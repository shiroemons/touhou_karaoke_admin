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
    url = Constants::Karaoke::Joysound::BASE_URL
    browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 2000], browser_options: { 'no-sandbox': nil })

    music_port_artists = JoysoundMusicPost.distinct.pluck(:artist).sort
    exist_artists = DisplayArtist.music_post.distinct.pluck(:name).sort
    artists = music_port_artists - exist_artists
    error_artist = []

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
        browser.goto(url)
        # 検索対象を 歌手名 に変更
        browser.at_xpath('//*[@id="jp-cmp-header-select-keywordtype"]').select(["artist"])
        # 検索キーワードのinput
        input = browser.at_xpath('//*[@id="jp-cmp-header-input-keyword"]')
        # 検索キーワードに アーティスト名を入力し、Enterキーで検索
        input.focus.type(artist, :Enter)
        # 描画に少し時間がかかるため 1秒待つ
        sleep(1.0)

        result_list_selector = "#searchresult > ul > li"
        browser.css(result_list_selector).each do |el|
          no_data = el.inner_text
          if no_data == "該当データがありません"
            JoysoundMusicPost.where(artist:)&.destroy_all
            DisplayArtist.find_by(name: artist, karaoke_type: "JOYSOUND(うたスキ)")&.destroy
          else
            option = el.at_css("div > div > div.jp-cmp-list-inline-003").inner_text
            option.gsub!("ウィキペディア", "")
            next if option.present?

            display_artist = el.at_css("h3.jp-cmp-music-title-001").inner_text
            display_artist.gsub!(" 新曲あり", "")
            next if artist != display_artist

            artist_url = el.at_css("a").property("href")
            next if DisplayArtist.exists?(name: artist, karaoke_type: "JOYSOUND(うたスキ)", url: artist_url)

            # 別ブラウザを起動する
            sub_browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 2000], browser_options: { 'no-sandbox': nil })
            sub_browser.goto(artist_url)
            sleep(1.0)
            artist_selector = "#jp-cmp-main > section:nth-child(2) > header > div.jp-cmp-h1-003-title > h1 > span"
            artist_el = sub_browser.at_css(artist_selector)
            name_reading = artist_el.inner_text.gsub(/[（）]/, "")

            DisplayArtist.find_or_create_by!(name: display_artist, name_reading:, karaoke_type: "JOYSOUND(うたスキ)", url: sub_browser.current_url)
            sub_browser.quit
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
    logger.debug("未登録アーティスト：#{error_artist}") if error_artist.present?
  end

  def self.register_joysound_music_post_artists(progress: nil)
    fetch_joysound_music_post_artist(progress:)
  end

  def self.progress_percentage(current, total)
    return 96 if total.to_i.zero?

    (8 + (88 * (current.to_f / total))).floor.clamp(8, 96)
  end
end
