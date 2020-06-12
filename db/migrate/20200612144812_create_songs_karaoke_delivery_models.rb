class CreateSongsKaraokeDeliveryModels < ActiveRecord::Migration[6.0]
  def change
    create_table :songs_karaoke_delivery_models, id: :uuid do |t|
      t.references :song, type: :uuid, null: false, foreign_key: true
      t.references :karaoke_delivery_model, type: :uuid, null: false, foreign_key: true, index: false
      t.index :karaoke_delivery_model_id, name: "idx_songs_karaoke_delivery_models_on_karaoke_delivery_model_id"

      t.timestamps
    end

  end
end
