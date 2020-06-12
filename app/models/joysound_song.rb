class JoysoundSong < ApplicationRecord
  validates :display_title, presence: true
  validates :url, presence: true
end
