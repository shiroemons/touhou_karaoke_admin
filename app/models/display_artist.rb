class DisplayArtist < ApplicationRecord
  has_many :display_artists_circles, -> { order(:created_at, :id) }, dependent: :destroy, inverse_of: :display_artist
  has_many :circles, through: :display_artists_circles
  has_many :songs, dependent: :destroy
  has_many :dam_songs, dependent: :destroy

  scope :dam, -> { where(karaoke_type: "DAM") }
  scope :joysound, -> { where(karaoke_type: "JOYSOUND") }
  scope :music_post, -> { where(karaoke_type: "JOYSOUND(うたスキ)") }
  scope :name_reading_empty, -> { where(name_reading: "") }

  def self.ransackable_attributes(_auth_object = nil)
    ["name"]
  end

  def self.fetch_joysound_artist(progress: nil)
    Scrapers::JoysoundArtistScraper.new.fetch_artist_readings(progress:)
  end

  def self.fill_joysound_artist_readings(progress: nil)
    fetch_joysound_artist(progress:)
  end

  def self.fill_dam_artist_readings(progress: nil)
    DamArtistUrl.fill_dam_artist_readings(progress:)
  end

  def self.fetch_joysound_music_post_artist(progress: nil)
    Scrapers::JoysoundArtistScraper.new.register_music_post_artists(progress:)
  end

  def self.register_joysound_music_post_artists(progress: nil)
    fetch_joysound_music_post_artist(progress:)
  end

  def self.progress_percentage(current, total)
    Scrapers::JoysoundArtistScraper.progress_percentage(current, total)
  end

  def self.joysound_artist_search_url(artist)
    Scrapers::JoysoundArtistScraper.search_url(artist)
  end

  def self.joysound_artist_search_no_data?(browser)
    Scrapers::JoysoundArtistScraper.search_no_data?(browser)
  end

  def self.joysound_artist_search_result_links(browser)
    Scrapers::JoysoundArtistScraper.search_result_links(browser)
  end

  def self.joysound_artist_search_result_name(link)
    Scrapers::JoysoundArtistScraper.search_result_name(link)
  end

  def self.joysound_artist_name_reading(browser, artist)
    Scrapers::JoysoundArtistScraper.name_reading(browser, artist)
  end

  def self.absolute_joysound_url(path)
    Scrapers::JoysoundArtistScraper.absolute_joysound_url(path)
  end
end
