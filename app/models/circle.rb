class Circle < ApplicationRecord
  has_many :display_artists_circles, dependent: :destroy
  has_many :display_artists, through: :display_artists_circles
end
