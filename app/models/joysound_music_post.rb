class JoysoundMusicPost < ApplicationRecord
  validates :title, presence: true
  validates :artist, presence: true
  validates :producer, presence: true
  validates :delivery_deadline_on, presence: true
  validates :url, presence: true

  def self.fetch_music_post
    url_zun = "https://musicpost.joysound.com/musicList/page:1?target=5&method=1&keyword=ZUN&detail_show_flg=false&original=on&cover=on&sort=1"
    url_u2 = "https://musicpost.joysound.com/musicList/page:1?target=5&method=1&keyword=%E3%81%82%E3%81%8D%E3%82%84%E3%81%BE%E3%81%86%E3%81%AB&detail_show_flg=false&original=on&cover=on&sort=1"

    browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900])
    music_post_parser(browser, url_zun)
    music_post_parser(browser, url_u2)
    browser.quit
  end

  def self.fetch_music_post_song_joysound_url
    browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 2000])
    search_option = "?sortOrder=new&orderBy=desc&startIndex=0#songlist"

    display_artists = DisplayArtist.music_post
    display_artists.each do |da|
      url = da.url + search_option
      browser.goto(url)

      loop do
        song_list_selector = "#songlist > div.jp-cmp-music-list-001.jp-cmp-music-list-song-002 > ul > li"
        browser.css(song_list_selector).each do |el|
          url_path = el.at_css("a").attribute("href")
          url = URI.join("https://www.joysound.com/", url_path).to_s
          display_title = el.at_css("div > a > h3").inner_text
          title = display_title.split("／").first
          record = JoysoundMusicPost.find_by(artist: da.name, title: title)
          if record
            record.joysound_url = url
            record.save! if record.changed?
          end
        end

        next_selector = "nav > div.jp-cmp-sp-none > div.jp-cmp-btn-pager-next.ng-scope.ng-scope"
        next_text = browser.at_css(next_selector)&.inner_text
        if next_text == "次の20件"
          browser.at_css(next_selector).at_css("a").focus.click
          sleep(1.0)
        else
          break
        end
      end
    end
  rescue => e
    logger.error(e)
    browser.screenshot(path: "tmp/music_post.png")
  end

  private

  def self.music_post_parser(browser, url)
    browser.goto(url)
    browser.network.wait_for_idle(duration: 1.0)
    loop do
      music_block_selector = "#box_music_list_bottom > div.music_block"
      browser.css(music_block_selector).each do |el|
        music_post_url = el.at_css("a").property("href")

        title_selector = "div > span.music_name"
        title = el.at_css(title_selector).inner_text.gsub(/[[:space:]]/, " ").gsub("  ", " ")
        artist_selector = "div > span.artist_name"
        artist = el.at_css(artist_selector).inner_text.gsub(/[[:space:]]/, " ").gsub("  ", " ")
        producer_selector = "div > span.producer_name"
        producer = el.at_css(producer_selector).inner_text.gsub("配信ユーザー:", "").squish
        delivery_status_selector = "div > span.delivery_status"
        delivery_status = el.at_css(delivery_status_selector).inner_text.gsub("配信期限:", "").squish
        delivery_deadline_on = Time.parse(delivery_status).strftime("%F")
        record = self.find_or_initialize_by(title: title, artist: artist, producer: producer, url: music_post_url)
        record.delivery_deadline_on = delivery_deadline_on
        if record.new_record? || record.changed?
          record.save!
        end
      end
      nav_selector = "#pager_bottom > div > a"
      next_link = nil
      browser.css(nav_selector).each do |el|
        next_box = el.at_css("span.next_page.page.box")&.inner_text
        if next_box&.start_with?("次へ")
          next_link = el
        end
      end
      if next_link.present?
        next_link.focus.click
      else
        break
      end
    end
  end
end
