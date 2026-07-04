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
    unique_ids = karaoke_delivery_model_ids.uniq

    # 既存の紐付けをまとめて取得し、ループ内で1件ずつSELECTしないようにする
    associations_by_delivery_model_id = where(song_id:, karaoke_delivery_model_id: unique_ids).index_by(&:karaoke_delivery_model_id)
    missing_ids = unique_ids - associations_by_delivery_model_id.keys

    if missing_ids.any?
      # belongs_to の存在確認バリデーションがcreate!のたびにSELECTしないよう、
      # songとkaraoke_delivery_modelを事前にまとめて読み込んでおく
      song = Song.find(song_id)
      karaoke_delivery_models_by_id = KaraokeDeliveryModel.where(id: missing_ids).index_by(&:id)

      missing_ids.each do |delivery_model_id|
        karaoke_delivery_model = karaoke_delivery_models_by_id[delivery_model_id]
        next unless karaoke_delivery_model

        associations_by_delivery_model_id[delivery_model_id] = create_association_without_lookup(song, karaoke_delivery_model)
      end
    end

    karaoke_delivery_model_ids.filter_map { |delivery_model_id| associations_by_delivery_model_id[delivery_model_id] }
  end

  # 事前チェック済みの新規紐付けを作成する（重複時のみ再検索する）
  def self.create_association_without_lookup(song, karaoke_delivery_model)
    create!(song:, karaoke_delivery_model:)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    # 事前チェック後に他のプロセスが同時に作成した場合
    find_by!(song_id: song.id, karaoke_delivery_model_id: karaoke_delivery_model.id)
  end
  private_class_method :create_association_without_lookup
end
