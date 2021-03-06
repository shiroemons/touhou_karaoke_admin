class DamArtistUrl < ApplicationRecord
  validates :url, presence: true

  def self.fetch_dam_artist
    @browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900])
    DamArtistUrl.all.each do |dau|
      dam_artist_page_parser(dau.url)
    end
    @browser.quit
  end

  def self.dam_artist_page_parser(url)
    retry_count = 0
    begin
      @browser.goto(url)
      sleep(1.0)
      name_selector = "#anchor-pagetop > main > div > div > div.main-content > div.artist-detail > h2.artist-name"
      name = @browser.at_css(name_selector).inner_text
      name_reading_selector = "#anchor-pagetop > main > div > div > div.main-content > div.artist-detail > div.artist-yomi"
      name_reading = @browser.at_css(name_reading_selector).inner_text.gsub(/[\[\] ]/, "")
      if name.present? && name_reading.present?
        record = DisplayArtist.find_or_initialize_by(karaoke_type: "DAM", url: url)
        record.name = name
        record.name_reading = name_reading
        record.save! if record.changed?
      end
    rescue Ferrum::TimeoutError => ex
      logger.error(ex)
      @browser.network.clear(:traffic)
      retry_count += 1
      retry unless retry_count > 3
    end
  end
end
