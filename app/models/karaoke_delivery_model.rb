class KaraokeDeliveryModel < ApplicationRecord
  self.implicit_order_column = "order"
  acts_as_list column: :order

  has_many :songs_karaoke_delivery_models, dependent: :destroy
  has_many :songs, through: :songs_karaoke_delivery_models

  validates :name, presence: true
  validates :karaoke_type, presence: true
  validates :name, uniqueness: { scope: :karaoke_type } # rubocop:disable Rails/UniqueValidationWithoutIndex

  def self.ransackable_attributes(_auth_object = nil)
    %w[name karaoke_type]
  end
end
