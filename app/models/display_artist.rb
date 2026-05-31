class DisplayArtist < ApplicationRecord
  has_many :display_artists_circles, -> { order(:created_at, :id) }, dependent: :destroy, inverse_of: :display_artist
  has_many :circles, through: :display_artists_circles
  has_many :songs, dependent: :destroy
  has_many :dam_songs, dependent: :destroy

  scope :dam, -> { where(karaoke_type: "DAM") }
  scope :joysound, -> { where(karaoke_type: "JOYSOUND") }
  scope :music_post, -> { where(karaoke_type: "JOYSOUND(うたスキ)") }
  scope :name_reading_empty, -> { where(name_reading: "") }

  def self.ransackable_attributes(_auth_object = nil)
    ["name"]
  end

  def self.fetch_joysound_artist(progress: nil)
    browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
    total_count = DisplayArtist.joysound.name_reading_empty.count
    DisplayArtist.joysound.name_reading_empty.each.with_index(1) do |da, i|
      logger.debug("#{i}/#{total_count}: #{((i / total_count.to_f) * 100).floor}%")
      progress&.call(
        percentage: progress_percentage(i - 1, total_count),
        status: "JOYSOUNDアーティスト取得中",
        label: "JOYSOUNDアーティスト読みを取得しています",
        detail: "処理済み: #{i - 1}/#{total_count}件",
        current: i - 1,
        total: total_count
      )
      browser.goto(da.url)
      browser.network.wait_for_idle(duration: 1.0)

      artist_selector = "#jp-cmp-main > section:nth-child(2) > header > div.jp-cmp-h1-003-title > h1 > span"
      artist_el = browser.at_css(artist_selector)
      name_reading = artist_el&.inner_text&.gsub(/[（）]/, "")

      if name_reading.present?
        logger.debug(name_reading)
        da.name_reading = name_reading
        da.save!
      end
      progress&.call(
        percentage: progress_percentage(i, total_count),
        status: "JOYSOUNDアーティスト取得中",
        label: "JOYSOUNDアーティスト読みを取得しています",
        detail: "処理済み: #{i}/#{total_count}件",
        current: i,
        total: total_count
      )
    end
  end

  def self.fill_joysound_artist_readings(progress: nil)
    fetch_joysound_artist(progress:)
  end

  def self.fill_dam_artist_readings(progress: nil)
    DamArtistUrl.fill_dam_artist_readings(progress:)
  end

  def self.fetch_joysound_music_post_artist(progress: nil)
    browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 2000], browser_options: { 'no-sandbox': nil })

    music_port_artists = JoysoundMusicPost.distinct.pluck(:artist).sort
    completed_artists = DisplayArtist.music_post.where.not(name_reading: [nil, ""]).distinct.pluck(:name).sort
    artists = music_port_artists - completed_artists
    error_artist = []

    begin
      artists.each.with_index(1) do |artist, index|
        progress&.call(
          percentage: progress_percentage(index - 1, artists.count),
          status: "ミュージックポストアーティスト取得中",
          label: "ミュージックポストアーティストを検索しています",
          detail: "処理済み: #{index - 1}/#{artists.count}件",
          current: index - 1,
          total: artists.count
        )
        rescue_count = 0
        begin
          browser.goto(joysound_artist_search_url(artist))
          browser.network.wait_for_idle(duration: 1.0)

          if joysound_artist_search_no_data?(browser)
            JoysoundMusicPost.where(artist:).destroy_all
            DisplayArtist.find_by(name: artist, karaoke_type: "JOYSOUND(うたスキ)")&.destroy
          else
            artist_link = joysound_artist_search_result_links(browser).find do |link|
              joysound_artist_search_result_name(link) == artist
            end

            if artist_link.present?
              artist_url = absolute_joysound_url(artist_link.attribute("href").to_s)
              display_artist = DisplayArtist.find_or_initialize_by(name: artist, karaoke_type: "JOYSOUND(うたスキ)")

              if display_artist.new_record? || display_artist.url != artist_url || display_artist.name_reading.blank?
                browser.goto(artist_url)
                browser.network.wait_for_idle(duration: 1.0)
                display_artist.name_reading = joysound_artist_name_reading(browser, artist)
                display_artist.url = browser.current_url
                display_artist.save!
              end
            end
          end
        rescue Ferrum::NodeNotFoundError => e
          logger.debug(e)
          rescue_count += 1
          if rescue_count > 3
            browser.screenshot(path: "tmp/music_post_#{artist.tr('/', '／')}.png")
            error_artist << artist
          else
            browser.network.clear(:traffic)
            retry
          end
        end
        progress&.call(
          percentage: progress_percentage(index, artists.count),
          status: "ミュージックポストアーティスト取得中",
          label: "ミュージックポストアーティストを検索しています",
          detail: "処理済み: #{index}/#{artists.count}件",
          current: index,
          total: artists.count
        )
      end
    ensure
      browser.quit
    end
    logger.debug("未登録アーティスト：#{error_artist}") if error_artist.present?
  end

  def self.register_joysound_music_post_artists(progress: nil)
    fetch_joysound_music_post_artist(progress:)
  end

  def self.progress_percentage(current, total)
    return 96 if total.to_i.zero?

    (8 + (88 * (current.to_f / total))).floor.clamp(8, 96)
  end

  def self.joysound_artist_search_url(artist)
    uri = URI.join(Constants::Karaoke::Joysound::BASE_URL, "search/artist")
    uri.query = URI.encode_www_form(match: 1, keyword: artist)
    uri.to_s
  end

  def self.joysound_artist_search_no_data?(browser)
    browser.at_css("body")&.inner_text.to_s.include?("該当データがありません")
  end

  def self.joysound_artist_search_result_links(browser)
    browser.css('a[href^="/web/search/artist/"]')
  end

  def self.joysound_artist_search_result_name(link)
    link.css("p").map { |node| node.inner_text.to_s.strip }.find(&:present?) ||
      link.inner_text.to_s.gsub(/\A新曲あり/, "").strip
  end

  def self.joysound_artist_name_reading(browser, artist)
    reading = browser.css("main section p").map { |node| node.inner_text.to_s.strip }.find do |text|
      text.match?(/\A[（(].+[）)]\z/)
    end
    lines = browser.at_css("body")&.inner_text.to_s.lines.map(&:strip).compact_blank
    artist_index = lines.index(artist)
    reading ||= lines[(artist_index || -1) + 1] if artist_index

    return "" unless reading&.match?(/\A[（(].+[）)]\z/)

    reading.gsub(/[（）()]/, "")
  end

  def self.absolute_joysound_url(path)
    URI.join(Constants::Karaoke::Joysound::BASE_URL, path).to_s
  end
end
