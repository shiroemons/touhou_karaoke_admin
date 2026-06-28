class SongsOriginalSong < ApplicationRecord
  belongs_to :original_song, foreign_key: :original_song_code, inverse_of: :songs_original_songs, primary_key: :code
  belongs_to :song

  # Existing data can contain duplicates; keep this application guard until a non-destructive cleanup is complete.
  # rubocop:disable Rails/UniqueValidationWithoutIndex
  validates :original_song_code, uniqueness: { scope: :song_id }
  # rubocop:enable Rails/UniqueValidationWithoutIndex
end
