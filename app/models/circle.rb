class Circle < ApplicationRecord
  has_many :display_artists_circles, -> { order(:created_at, :id) }, dependent: :destroy, inverse_of: :circle
  has_many :display_artists, through: :display_artists_circles

  has_many :songs, through: :display_artists

  delegate :count, to: :display_artists, prefix: true
  delegate :count, to: :songs, prefix: true

  def self.ransackable_attributes(_auth_object = nil)
    ["name"]
  end
end
