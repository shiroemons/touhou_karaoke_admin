class DisplayArtist < ApplicationRecord
  has_many :display_artists_circles
  has_many :circles, through: :display_artists_circles
  has_many :songs
end
