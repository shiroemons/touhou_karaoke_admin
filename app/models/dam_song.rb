class DamSong < ApplicationRecord
  belongs_to :display_artist

  # Existing data can contain duplicates; keep this application guard until a non-destructive cleanup is complete.
  # rubocop:disable Rails/UniqueValidationWithoutIndex
  validates :url, presence: true, uniqueness: true
  # rubocop:enable Rails/UniqueValidationWithoutIndex
  validates :title, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    ["title"]
  end

  def self.fetch_dam_song(song_url)
    Scrapers::DamSongScraper.new.fetch_song(song_url)
  end

  def self.fetch_dam_touhou_songs(progress: nil)
    Scrapers::DamSongScraper.new.fetch_touhou_songs(progress:)
  end

  def self.fetch_dam_candidate_songs(progress: nil)
    fetch_dam_touhou_songs(progress:)
  end

  def self.detect_dam_search_total_pages(browser, page_size)
    Scrapers::DamSongScraper.detect_total_pages(browser, page_size)
  end

  def self.dam_touhou_progress_percentage(page:, item_index:, item_count:, total_pages:)
    Scrapers::DamSongScraper.progress_percentage(page:, item_index:, item_count:, total_pages:)
  end

  def self.dam_song_list_parser(display_artist)
    Scrapers::DamSongScraper.new.parse_artist_song_list(display_artist)
  end
end
