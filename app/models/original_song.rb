class OriginalSong < ApplicationRecord
  self.primary_key = :code

  has_many :songs_original_songs, foreign_key: :original_song_code, inverse_of: :original_song, dependent: :destroy
  has_many :songs, through: :songs_original_songs

  belongs_to :original,
             foreign_key: :original_code,
             primary_key: :code,
             inverse_of: :original_songs

  delegate :short_title, to: :original, allow_nil: true, prefix: true

  scope :non_duplicated, -> { where(is_duplicate: false) }
end
