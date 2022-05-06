class SongsOriginalSong < ApplicationRecord
  belongs_to :original_song, foreign_key: :original_song_code, inverse_of: :songs_original_songs, primary_key: :code
  belongs_to :song
end
