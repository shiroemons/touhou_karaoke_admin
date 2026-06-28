class DisplayArtistsCircle < ApplicationRecord
  belongs_to :display_artist
  belongs_to :circle

  # Existing data can contain duplicates; keep this application guard until a non-destructive cleanup is complete.
  # rubocop:disable Rails/UniqueValidationWithoutIndex
  validates :circle_id, uniqueness: { scope: :display_artist_id }
  # rubocop:enable Rails/UniqueValidationWithoutIndex
end
