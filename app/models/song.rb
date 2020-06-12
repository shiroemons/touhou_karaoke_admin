class Song < ApplicationRecord
  has_many :songs_karaoke_delivery_models
  has_many :karaoke_delivery_models, through: :songs_karaoke_delivery_models
  has_many :songs_original_songs
  has_many :original_songs, through: :songs_original_songs

  belongs_to :display_artist
end
