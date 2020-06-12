class KaraokeDeliveryModel < ApplicationRecord
  self.implicit_order_column = "order"

  has_many :songs_karaoke_delivery_models
  has_many :songs, through: :songs_karaoke_delivery_models
end
