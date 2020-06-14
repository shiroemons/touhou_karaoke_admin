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

  private

  def self.music_post_parser(browser, url)
    base_url = "https://musicpost.joysound.com/"
    browser.goto(url)
    loop do
      music_block_selector = "#box_music_list_bottom > div.music_block"
      browser.css(music_block_selector).each do |el|
        url_path = el.at_css("a").attribute("href")
        url = URI.join(base_url, url_path).to_s

        title_selector = "div > span.music_name"
        title = el.at_css(title_selector).inner_text.gsub(/[[:space:]]/, " ").gsub("  ", " ")
        artist_selector = "div > span.artist_name"
        artist = el.at_css(artist_selector).inner_text.gsub(/[[:space:]]/, " ").gsub("  ", " ")
        producer_selector = "div > span.producer_name"
        producer = el.at_css(producer_selector).inner_text.gsub("配信ユーザー:", "").squish
        delivery_status_selector = "div > span.delivery_status"
        delivery_status = el.at_css(delivery_status_selector).inner_text.gsub("配信期限:", "").squish
        delivery_deadline_on = Time.parse(delivery_status).strftime("%F")
        record = self.find_or_initialize_by(title: title, artist: artist, producer: producer, url: url)
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
