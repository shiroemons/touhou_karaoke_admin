class DamArtistUrl < ApplicationRecord
  validates :url, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    ["url"]
  end

  def self.fetch_dam_artist
    DamArtistUrl.all.find_each do |dau|
      next unless DisplayArtist.exists?(karaoke_type: "DAM", url: dau.url, name_reading: "")

      dam_artist_page_parser(dau.url)
    end
  end

  def self.dam_artist_page_parser(url)
    retry_count = 0
    @browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })

    begin
      @browser.goto(url)
      @browser.network.wait_for_idle(duration: 1.0)
      name_selector = "#anchor-pagetop > main > div > div > div.main-content > div.artist-detail > h2.artist-name"
      name = @browser.at_css(name_selector).inner_text
      name_reading_selector = "#anchor-pagetop > main > div > div > div.main-content > div.artist-detail > div.artist-yomi"
      name_reading = @browser.at_css(name_reading_selector).inner_text.gsub(/[\[\] ]/, "")
      if name.present? && name_reading.present?
        record = DisplayArtist.find_or_initialize_by(karaoke_type: "DAM", url:)
        record.name = name
        record.name_reading = name_reading
        record.save! if record.changed?
      end
      @browser.quit
    rescue StandardError => e
      logger.error(e)
      @browser.quit
      @browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
      retry_count += 1
      retry unless retry_count > 3
    end
  end
end
