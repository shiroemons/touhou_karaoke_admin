class CreateKaraokeDeliveryModels < ActiveRecord::Migration[6.0]
  def change
    create_table :karaoke_delivery_models, id: :uuid do |t|
      t.string :name, null: false
      t.string :karaoke_type, null: false
      t.integer :order, null: false

      t.timestamps
    end
  end
end
