class JoysoundMusicPost < ApplicationRecord
  validates :title, presence: true
  validates :artist, presence: true
  validates :producer, presence: true
  validates :delivery_deadline_on, presence: true
  validates :url, presence: true
  # Existing data can contain duplicates; keep this application guard until a non-destructive cleanup is complete.
  # rubocop:disable Rails/UniqueValidationWithoutIndex
  validates :url, uniqueness: true
  # rubocop:enable Rails/UniqueValidationWithoutIndex

  def self.ransackable_attributes(_auth_object = nil)
    %w[artist title]
  end

  def self.fetch_music_post(progress: nil)
    JoysoundMusicPostFetcher.fetch_music_post(progress:)
  end

  def self.fetch_music_post_entries(progress: nil)
    fetch_music_post(progress:)
  end

  def self.fetch_music_post_song_joysound_url(progress: nil)
    JoysoundMusicPostFetcher.fetch_music_post_song_joysound_url(progress:)
  end

  def self.link_music_posts_to_joysound_urls(progress: nil)
    fetch_music_post_song_joysound_url(progress:)
  end

  def self.music_post_parser(url, progress: nil, progress_range: 8..96, label: "ミュージックポストを取得しています")
    JoysoundMusicPostFetcher.music_post_parser(url, progress:, progress_range:, label:)
  end

  def self.progress_percentage(current, total)
    JoysoundMusicPostFetcher.progress_percentage(current, total)
  end

  def self.unknown_page_progress(page, item_index, item_count, progress_range)
    JoysoundMusicPostFetcher.unknown_page_progress(page, item_index, item_count, progress_range)
  end

  def self.joysound_song_links(browser)
    JoysoundMusicPostFetcher.joysound_song_links(browser)
  end

  def self.joysound_song_link_title(link)
    JoysoundMusicPostFetcher.joysound_song_link_title(link)
  end

  def self.joysound_artist_next_song_list_link(browser)
    JoysoundMusicPostFetcher.joysound_artist_next_song_list_link(browser)
  end

  def self.absolute_joysound_url(path)
    JoysoundMusicPostFetcher.absolute_joysound_url(path)
  end
end
