class JoysoundSong < ApplicationRecord
  validates :display_title, presence: true
  validates :url, presence: true

  scope :enabled_smartphone_service, -> { where(smartphone_service_enabled: true) }
  scope :enabled_home_karaoke, -> { where(home_karaoke_enabled: true) }

  def self.ransackable_attributes(_auth_object = nil)
    ["display_title"]
  end

  def self.add_delivery_model
    smartphone_service = KaraokeDeliveryModel.find_by(karaoke_type: "JOYSOUND", name: "スマホサービス")
    home_karaoke = KaraokeDeliveryModel.find_by(karaoke_type: "JOYSOUND", name: "家庭用カラオケ")
    enabled_smartphone_service.each do |js|
      title = js.display_title.split("／").first
      url = js.url
      song = Song.find_by(title:, url:, karaoke_type: "JOYSOUND")
      song.karaoke_delivery_models << smartphone_service if song.present? && !song.karaoke_delivery_models&.include?(smartphone_service)
    end
    enabled_home_karaoke.each do |js|
      title = js.display_title.split("／").first
      url = js.url
      song = Song.find_by(title:, url:, karaoke_type: "JOYSOUND")
      song.karaoke_delivery_models << home_karaoke if song.present? && !song.karaoke_delivery_models&.include?(home_karaoke)
    end
  end

  def self.fetch_joysound_touhou_songs
    url = Constants::Karaoke::Joysound::TOUHOU_GENRE_URL

    browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
    browser.goto(url)
    browser.network.wait_for_idle(duration: 1.0)

    song_selector = "#jp-cmp-main > section > jp-cmp-song-search-list > div.jp-cmp-music-list-001.jp-cmp-music-list-song-001 > ul > li"

    page_counter = 1
    loop do
      logger.info("[INFO] page #{page_counter}.")
      browser.css(song_selector).each do |el|
        url = el.at_css("div > a").property("href")
        display_title = el.at_css("div > a > h3").inner_text.gsub(" 新曲", "")
        smartphone_service = false
        home_karaoke = false
        el.css("div > a > div > ul > li > span").each do |tag|
          case tag.inner_text
          when "スマホサービス"
            smartphone_service = true
          when "家庭用カラオケ"
            home_karaoke = true
          end
        end
        record = find_or_initialize_by(display_title:, url:)
        record.smartphone_service_enabled = smartphone_service
        record.home_karaoke_enabled = home_karaoke
        record.save! if record.changed?
      end

      next_selector = "nav > div.jp-cmp-sp-none > div.jp-cmp-btn-pager-next.ng-scope.ng-scope"
      next_text = browser.at_css(next_selector)&.inner_text
      if next_text == "次の20件"
        browser.at_css(next_selector).at_css("a").focus.click
        browser.network.wait_for_idle(duration: 1.0)
        page_counter += 1
      else
        puts "最後のページ"
        break
      end
    end
    browser.quit
  end

  def self.fetch_joysound_song_direct(url: nil)
    browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
    browser.goto(url)
    browser.network.wait_for_idle(duration: 1.0)

    display_title_selector = "#jp-cmp-main > section:nth-child(2) > header > h1"
    display_title = browser.at_css(display_title_selector).text

    record = find_or_initialize_by(display_title:, url:)
    smartphone_service = false
    home_karaoke = false
    record.smartphone_service_enabled = smartphone_service
    record.home_karaoke_enabled = home_karaoke
    record.save! if record.changed?
    browser.quit
  end
end
