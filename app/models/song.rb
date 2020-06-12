class Song < ApplicationRecord
  has_many :songs_karaoke_delivery_models
  has_many :karaoke_delivery_models, through: :songs_karaoke_delivery_models

  belongs_to :display_artist
end
