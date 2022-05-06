class OriginalSong < ApplicationRecord
  self.primary_key = :code

  has_many :songs_original_songs, foreign_key: :original_song_code
  has_many :songs, through: :songs_original_songs

  belongs_to :original,
             foreign_key: :original_code,
             primary_key: :code,
             inverse_of: :original_songs
end
