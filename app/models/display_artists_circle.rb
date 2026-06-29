class DisplayArtistsCircle < ApplicationRecord
  belongs_to :display_artist
  belongs_to :circle

  validates :circle_id, uniqueness: { scope: :display_artist_id }
end
