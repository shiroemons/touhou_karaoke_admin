class SongWithDamOuchikaraoke < ApplicationRecord
  belongs_to :song

  # Existing data can contain duplicates; keep this application guard until a non-destructive cleanup is complete.
  # rubocop:disable Rails/UniqueValidationWithoutIndex
  validates :song_id, uniqueness: true
  validates :url, presence: true, uniqueness: true
  # rubocop:enable Rails/UniqueValidationWithoutIndex
end
