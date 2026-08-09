class SongWithJoysoundUtasuki < ApplicationRecord
  class Conflict < StandardError; end

  belongs_to :song

  validates :song_id, uniqueness: true
  validates :url, presence: true, uniqueness: true
end
