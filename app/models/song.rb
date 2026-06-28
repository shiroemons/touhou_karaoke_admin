class Song < ApplicationRecord
  include Categorizable
  include ParallelProcessor

  has_one :song_with_dam_ouchikaraoke, dependent: :destroy
  has_one :song_with_joysound_utasuki, dependent: :destroy

  has_many :songs_karaoke_delivery_models, dependent: :destroy
  has_many :karaoke_delivery_models, -> { order(order: :desc) }, through: :songs_karaoke_delivery_models, inverse_of: :songs
  has_many :songs_original_songs, dependent: :destroy
  has_many :original_songs, through: :songs_original_songs, inverse_of: :songs

  belongs_to :display_artist

  ORIGINAL_OR_OTHER_TITLES = %w[オリジナル その他].freeze

  scope :missing_original_songs, -> { where.missing(:songs_original_songs) }
  scope :with_original_songs, -> { joins(:songs_original_songs).distinct }
  scope :dam, -> { where(karaoke_type: "DAM") }
  scope :joysound, -> { where(karaoke_type: "JOYSOUND") }
  scope :music_post, -> { where(karaoke_type: "JOYSOUND(うたスキ)") }
  scope :touhou_arrange, -> { joins(:original_songs).where.not(original_songs: { title: Song::ORIGINAL_OR_OTHER_TITLES }).distinct }
  scope :original_or_other, -> { with_original_songs.where.not(id: touhou_arrange.select(:id)) }
  scope :youtube, -> { where.not(youtube_url: "") }
  scope :apple_music, -> { where.not(apple_music_url: "") }
  scope :youtube_music, -> { where.not(youtube_music_url: "") }
  scope :spotify, -> { where.not(spotify_url: "") }
  scope :line_music, -> { where.not(line_music_url: "") }

  def self.ransackable_attributes(_auth_object = nil)
    ["title"]
  end

  def touhou?
    original_song_category_label == "東方アレンジ"
  end

  def original_songs_link_status
    original_songs.present? ? "あり" : "なし"
  end

  def original_songs_count_label
    "#{original_songs.size}曲"
  end

  def original_song_category_label
    return "未紐付け" if original_songs.blank?

    original_songs.all? { |original_song| original_song.title.in?(ORIGINAL_OR_OTHER_TITLES) } ? "オリジナル・その他" : "東方アレンジ"
  end

  def self.not_set_original_song
    includes(:display_artist, :original_songs).select do |song|
      song if song.original_songs.blank?
    end
  end

  def self.fetch_joysound_song(url = nil)
    SongExternalSync.fetch_joysound_song(url)
  end

  def self.fetch_joysound_songs(progress: nil)
    SongExternalSync.fetch_joysound_songs(progress:)
  end

  def self.register_joysound_songs_from_candidates(progress: nil)
    fetch_joysound_songs(progress:)
  end

  def self.fetch_joysound_music_post_song
    SongExternalSync.fetch_joysound_music_post_song
  end

  def self.register_joysound_music_post_songs
    fetch_joysound_music_post_song
  end

  def self.prioritized_joysound_music_posts
    SongExternalSync.prioritized_joysound_music_posts
  end

  def self.refresh_joysound_music_post_song
    SongExternalSync.refresh_joysound_music_post_song
  end

  def self.verify_joysound_music_post_songs
    refresh_joysound_music_post_song
  end

  def self.fetch_dam_songs(progress: nil)
    SongExternalSync.fetch_dam_songs(progress:)
  end

  def self.register_dam_songs_from_candidates(progress: nil)
    fetch_dam_songs(progress:)
  end

  def self.update_dam_delivery_models(progress: nil)
    SongExternalSync.update_dam_delivery_models(progress:)
  end

  def self.sync_dam_delivery_models(progress: nil)
    update_dam_delivery_models(progress:)
  end

  def self.update_joysound_music_post_delivery_deadline_dates
    SongExternalSync.update_joysound_music_post_delivery_deadline_dates
  end

  def self.sync_joysound_music_post_delivery_deadlines
    update_joysound_music_post_delivery_deadline_dates
  end
end
