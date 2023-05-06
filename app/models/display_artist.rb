class DisplayArtist < ApplicationRecord
  has_many :display_artists_circles, dependent: :destroy
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

  def self.fetch_joysound_artist
    browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
    total_count = DisplayArtist.joysound.name_reading_empty.count
    DisplayArtist.joysound.name_reading_empty.each.with_index(1) do |da, i|
      logger.debug("#{i}/#{total_count}: #{((i / total_count.to_f) * 100).floor}%")
      browser.goto(da.url)
      browser.network.wait_for_idle(duration: 1.0)

      artist_selector = "#jp-cmp-main > section:nth-child(2) > header > div.jp-cmp-h1-003-title > h1 > span"
      artist_el = browser.at_css(artist_selector)
      name_reading = artist_el&.inner_text&.gsub(/[（）]/, "")
      next if name_reading.blank?

      logger.debug(name_reading)
      da.name_reading = name_reading
      da.save!
    end
  end

  def self.fetch_joysound_music_post_artist
    url = "https://www.joysound.com/web/"
    browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 2000], browser_options: { 'no-sandbox': nil })

    artists = JoysoundMusicPost.distinct.pluck(:artist).sort
    error_artist = []

    artists.each do |artist|
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
    end
    logger.debug("未登録アーティスト：#{error_artist}") if error_artist.present?
  end
end
