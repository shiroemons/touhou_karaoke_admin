class JoysoundSong < ApplicationRecord
  validates :display_title, presence: true
  validates :url, presence: true

  scope :enabled_smartphone_service, -> { where(smartphone_service_enabled: true) }
  scope :enabled_home_karaoke, -> { where(home_karaoke_enabled: true) }

  def self.fetch_joysound_song
    base_url = "https://www.joysound.com/web/"
    url = "https://www.joysound.com/web/search/song?searchType=3&genreCd=22800001&sortOrder=new&orderBy=asc&startIndex=0#songlist"

    browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900])
    browser.goto(url)

    song_selector = "#jp-cmp-main > section > jp-cmp-song-search-list > div.jp-cmp-music-list-001.jp-cmp-music-list-song-001 > ul > li"

    page_counter = 1
    loop do
      logger.info("[INFO] page #{page_counter}.")
      browser.css(song_selector).each do |el|
        url_path = el.at_css("div > a").attribute("href")
        url = URI.join(base_url, url_path).to_s
        display_title = el.at_css("div > a > h3").inner_text
        smartphone_service = false
        home_karaoke = false
        el.css("div > a > div > ul > li > span").each do |tag|
          if tag.inner_text == "スマホサービス"
            smartphone_service = true
          elsif tag.inner_text == "家庭用カラオケ"
            home_karaoke = true
          end
        end
        record = self.find_or_initialize_by(display_title: display_title, url: url)
        record.smartphone_service_enabled = smartphone_service
        record.home_karaoke_enabled = home_karaoke
        if record.changed?
          record.save!
        end
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
  end
end
