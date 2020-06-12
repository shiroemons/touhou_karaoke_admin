class SongsKaraokeDeliveryModel < ApplicationRecord
  belongs_to :song
  belongs_to :karaoke_delivery_model
end
