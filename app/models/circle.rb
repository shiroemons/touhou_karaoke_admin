class Circle < ApplicationRecord
  has_many :display_artists_circles
  has_many :display_artists, through: :display_artists_circles
end
