# frozen_string_literal: true

module Scrapers
  class DamArtistScraper
    NAME_SELECTOR = "#anchor-pagetop > main > div > div > div.main-content > div.artist-detail > h2.artist-name"
    NAME_READING_SELECTOR = "#anchor-pagetop > main > div > div > div.main-content > div.artist-detail > div.artist-yomi"

    def scrape_artist_page(url)
      attempt = 0

      loop do
        attempt += 1
        browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
        browser.goto(url)
        browser.network.wait_for_idle(duration: 1.0)
        upsert_display_artist(url, browser)
        break
      rescue StandardError => e
        Rails.logger.error(e)
        break if attempt > 3
      ensure
        browser&.quit
      end
    end

    private

    def upsert_display_artist(url, browser)
      name = browser.at_css(NAME_SELECTOR).inner_text
      name_reading = browser.at_css(NAME_READING_SELECTOR).inner_text.gsub(/[\[\] ]/, "")
      return unless name.present? && name_reading.present?

      record = DisplayArtist.find_or_initialize_by(karaoke_type: "DAM", url:)
      record.name = name
      record.name_reading = name_reading
      record.save! if record.changed?
    end
  end
end
