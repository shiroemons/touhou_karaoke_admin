class AddUniqueConstraintToSongsKaraokeDeliveryModels < ActiveRecord::Migration[7.1]
  def change
    # song_id + karaoke_delivery_model_idの組み合わせにユニーク制約を追加
    # 同じ楽曲に同じ配信機種が重複して紐づくことを防ぐ
    add_index :songs_karaoke_delivery_models,
              %i[song_id karaoke_delivery_model_id],
              unique: true,
              name: 'index_songs_delivery_models_on_song_and_delivery_model'
  end
end
