class AddUniqueConstraintToKaraokeDeliveryModels < ActiveRecord::Migration[7.1]
  def change
    add_index :karaoke_delivery_models, %i[name karaoke_type], unique: true
  end
end
