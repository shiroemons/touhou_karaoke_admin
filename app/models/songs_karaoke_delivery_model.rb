class SongsKaraokeDeliveryModel < ApplicationRecord
  belongs_to :song
  belongs_to :karaoke_delivery_model

  # 同じ楽曲に同じ配信機種が重複して紐づくことを防ぐ
  validates :song_id, uniqueness: { scope: :karaoke_delivery_model_id }

  # 重複チェック付きの安全な作成メソッド
  def self.find_or_create_association(song_id, karaoke_delivery_model_id)
    find_or_create_by(song_id:, karaoke_delivery_model_id:)
  rescue ActiveRecord::RecordNotUnique
    # 他のプロセスが同時に作成した場合
    find_by!(song_id:, karaoke_delivery_model_id:)
  end

  # バッチでの安全な作成
  def self.create_associations_safely(song_id, karaoke_delivery_model_ids)
    karaoke_delivery_model_ids.filter_map do |delivery_model_id|
      find_or_create_association(song_id, delivery_model_id)
    end
  end
end
