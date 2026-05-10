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
    begin
      browser.goto(url)
      browser.network.wait_for_idle(duration: 1.0)

      song_selector = '[data-testid="card-information"]'
      song_link_selector = 'a[href^="/web/search/song/"]'

      page_counter = 1
      loop do
        logger.info("[INFO] page #{page_counter}.")
        browser.css(song_selector).each do |el|
          link = el.at_css(song_link_selector)
          next if link.blank?

          url = URI.join(Constants::Karaoke::Joysound::BASE_URL, link.attribute("href")).to_s
          display_title = joysound_display_title(link)
          next if display_title.blank?

          tags = el.css("span").map { |tag| tag.inner_text.strip }
          smartphone_service = tags.include?("スマホサービス")
          home_karaoke = tags.include?("家庭用カラオケ")

          record = find_or_initialize_by(display_title:, url:)
          record.smartphone_service_enabled = smartphone_service
          record.home_karaoke_enabled = home_karaoke
          record.save! if record.changed?
        end

        next_button = browser.css("nav button").find { |button| button.inner_text.strip == (page_counter + 1).to_s }
        if next_button.blank?
          puts "最後のページ"
          break
        end

        next_button.focus.click
        browser.network.wait_for_idle(duration: 1.0)
        sleep(1.0)
        page_counter += 1
      end
    ensure
      browser.quit
    end
  end

  def self.fetch_joysound_song_direct(url: nil)
    browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
    begin
      browser.goto(url)
      browser.network.wait_for_idle(duration: 1.0)

      display_title = browser.at_css('[data-testid="card-information"] p')&.text
      return if display_title.blank?

      record = find_or_initialize_by(display_title:, url:)
      smartphone_service = false
      home_karaoke = false
      record.smartphone_service_enabled = smartphone_service
      record.home_karaoke_enabled = home_karaoke
      record.save! if record.changed?
    ensure
      browser.quit
    end
  end

  def self.joysound_display_title(link)
    title = link.at_css("p")&.inner_text&.strip
    artist = link.at_css("div.font-medium")&.inner_text&.strip

    [title, artist].compact_blank.join("／")
  end
end
