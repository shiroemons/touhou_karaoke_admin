class JoysoundSong < ApplicationRecord
  validates :display_title, presence: true
  validates :url, presence: true
  # Existing data can contain duplicates; keep this application guard until a non-destructive cleanup is complete.
  # rubocop:disable Rails/UniqueValidationWithoutIndex
  validates :url, uniqueness: true
  # rubocop:enable Rails/UniqueValidationWithoutIndex

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

  def self.fetch_joysound_touhou_songs(progress: nil)
    Scrapers::JoysoundSongScraper.new.fetch_touhou_songs(progress:)
  end

  def self.fetch_joysound_candidate_songs(progress: nil)
    fetch_joysound_touhou_songs(progress:)
  end

  def self.fetch_joysound_song_direct(url: nil)
    Scrapers::JoysoundSongScraper.new.fetch_song_direct(url:)
  end

  def self.joysound_display_title(link)
    Scrapers::JoysoundSongScraper.display_title(link)
  end

  def self.detect_joysound_search_total_pages(browser, page_size)
    Scrapers::JoysoundSongScraper.detect_total_pages(browser, page_size)
  end

  def self.joysound_touhou_progress_percentage(page:, item_index:, item_count:, total_pages:)
    Scrapers::JoysoundSongScraper.progress_percentage(page:, item_index:, item_count:, total_pages:)
  end
end
