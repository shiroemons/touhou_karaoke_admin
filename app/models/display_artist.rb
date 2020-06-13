class DisplayArtist < ApplicationRecord
  has_many :display_artists_circles
  has_many :circles, through: :display_artists_circles
  has_many :songs

  scope :joysound, -> { where(karaoke_type: "JOYSOUND") }
  scope :name_reading_empty, -> { where(name_reading: "") }

  def self.fetch_joysound_artist
    browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900])
    total_count = DisplayArtist.joysound.name_reading_empty.count
    DisplayArtist.joysound.name_reading_empty.each.with_index(1) do |da, i|
      logger.debug("#{i}/#{total_count}: #{((i/total_count.to_f)*100).floor}%")
      browser.goto(da.url)

      artist_selector = "#jp-cmp-main > section:nth-child(2) > header > div.jp-cmp-h1-003-title > h1 > span"
      artist_el = browser.at_css(artist_selector)
      name_reading = artist_el.inner_text.gsub(/[（）]/, "")
      if name_reading.present?
        logger.debug(name_reading)
        da.name_reading = name_reading
        da.save!
      end
    end
  end

end
