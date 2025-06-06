class JoysoundMusicPost < ApplicationRecord
  validates :title, presence: true
  validates :artist, presence: true
  validates :producer, presence: true
  validates :delivery_deadline_on, presence: true
  validates :url, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[artist title]
  end

  def self.fetch_music_post
    url_zun = Constants::Karaoke::Joysound::MUSIC_POST_ZUN_URL
    url_u2 = Constants::Karaoke::Joysound::MUSIC_POST_AKIYAMA_URL

    music_post_parser(url_zun)
    music_post_parser(url_u2)
  end

  def self.fetch_music_post_song_joysound_url
    browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 2000], browser_options: { 'no-sandbox': nil })
    search_option = "?sortOrder=new&orderBy=desc&startIndex=0#songlist"

    artist_names = JoysoundMusicPost.where(joysound_url: "").pluck(:artist)
    display_artists = DisplayArtist.music_post.where(name: artist_names)
    display_artists.each do |da|
      url = da.url + search_option
      browser.goto(url)
      # 描画に少し時間がかかるため 1秒待つ
      sleep(1.0)

      loop do
        song_list_selector = "#songlist > div.jp-cmp-music-list-001.jp-cmp-music-list-song-002 > ul > li"
        browser.css(song_list_selector).each do |el|
          url_path = el.at_css("a").attribute("href")
          url = URI.join(Constants::Karaoke::Joysound::BASE_URL, url_path).to_s
          display_title = el.at_css("div > a > h3").inner_text
          title = display_title.split("／").first
          record = JoysoundMusicPost.find_by(artist: da.name, title:)
          if record
            record.joysound_url = url
            record.save! if record.changed?
          end
        end

        next_selector = "nav > div.jp-cmp-sp-none > div.jp-cmp-btn-pager-next.ng-scope.ng-scope"
        next_text = browser.at_css(next_selector)&.inner_text
        break unless next_text == "次の20件"

        browser.at_css(next_selector).at_css("a").focus.click
        sleep(1.0)
      end
    end
  rescue StandardError => e
    logger.error(e)
    browser.screenshot(path: "tmp/music_post.png")
  end

  def self.music_post_parser(url)
    browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
    retry_count = 0
    begin
      browser.goto(url)
      browser.network.wait_for_idle(duration: 1.0)
      loop do
        music_block_selector = "#box_music_list_bottom > div.music_block"
        browser.css(music_block_selector).each do |el|
          music_post_url = el.at_css("a").property("href")

          title_selector = "div > span.music_name"
          title = el.at_css(title_selector).inner_text.gsub(/[[:space:]]/, " ").gsub("  ", " ").strip
          artist_selector = "div > span.artist_name"
          artist = el.at_css(artist_selector).inner_text.gsub(/[[:space:]]/, " ").gsub("  ", " ").strip
          producer_selector = "div > span.producer_name"
          producer = el.at_css(producer_selector).inner_text.gsub("配信ユーザー:", "").squish
          delivery_status_selector = "div > span.delivery_status"
          delivery_status = el.at_css(delivery_status_selector).inner_text.gsub("配信期限:", "").squish
          delivery_deadline_on = Time.parse(delivery_status).in_time_zone.strftime("%F")
          record = find_or_initialize_by(title:, artist:, producer:, url: music_post_url)
          record.delivery_deadline_on = delivery_deadline_on
          record.save! if record.new_record? || record.changed?
        end
        nav_selector = "#pager_bottom > div > a"
        next_link = nil
        browser.css(nav_selector).each do |el|
          next_box = el.at_css("span.next_page.page.box")&.inner_text
          next_link = el if next_box&.start_with?("次へ")
        end

        break if next_link.blank?

        next_link.focus.click
      end
    end
    browser.quit
  rescue Ferrum::TimeoutError => e
    logger.error("self.music_post_parser: #{e}")
    browser.quit
    browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
    retry_count += 1
    retry unless retry_count > 3
  end
end
