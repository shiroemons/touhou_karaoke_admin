# frozen_string_literal: true

# パフォーマンス最適化版のJOYSOUNDスクレイパー
#
# 改善点：
#   1. バルクインサート/デリートでDB操作を削減
#   2. 不要なexists?チェックを削除
#   3. N+1クエリの回避
module Scrapers
  class OptimizedJoysoundScraper < JoysoundScraper
    private

    def update_delivery_models(song, new_delivery_model_ids)
      ActiveRecord::Base.transaction do
        # 現在の関連IDを一度のクエリで取得
        current_ids = song.songs_karaoke_delivery_models
                          .pluck(:karaoke_delivery_model_id)
        
        # 追加・削除すべきIDを計算
        ids_to_add = new_delivery_model_ids - current_ids
        ids_to_remove = current_ids - new_delivery_model_ids
        
        # バルク削除（1クエリ）
        if ids_to_remove.any?
          song.songs_karaoke_delivery_models
               .where(karaoke_delivery_model_id: ids_to_remove)
               .delete_all # destroyではなくdelete_allでコールバックをスキップ
        end
        
        # バルクインサート（1クエリ）
        if ids_to_add.any?
          now = Time.current
          records = ids_to_add.map do |model_id|
            {
              song_id: song.id,
              karaoke_delivery_model_id: model_id,
              created_at: now,
              updated_at: now
            }
          end
          
          SongsKaraokeDeliveryModel.insert_all(records)
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to update delivery models for song #{song.id}: #{e.message}")
      # エラーが発生しても処理を継続
    end

    # 複数の楽曲を一括で処理する最適化版
    def batch_update_delivery_models(songs_with_models)
      ActiveRecord::Base.transaction do
        song_ids = songs_with_models.keys
        
        # 現在の関連を一括取得
        current_associations = SongsKaraokeDeliveryModel
          .where(song_id: song_ids)
          .group_by(&:song_id)
        
        records_to_insert = []
        ids_to_delete = []
        
        songs_with_models.each do |song_id, new_model_ids|
          current_ids = current_associations[song_id]&.map(&:karaoke_delivery_model_id) || []
          
          # 削除対象を収集
          (current_ids - new_model_ids).each do |model_id|
            association = current_associations[song_id].find { |a| a.karaoke_delivery_model_id == model_id }
            ids_to_delete << association.id if association
          end
          
          # 追加対象を収集
          (new_model_ids - current_ids).each do |model_id|
            records_to_insert << {
              song_id: song_id,
              karaoke_delivery_model_id: model_id,
              created_at: Time.current,
              updated_at: Time.current
            }
          end
        end
        
        # バルク削除
        SongsKaraokeDeliveryModel.where(id: ids_to_delete).delete_all if ids_to_delete.any?
        
        # バルクインサート
        SongsKaraokeDeliveryModel.insert_all(records_to_insert) if records_to_insert.any?
      end
    end

    # キャッシュを活用したdelivery model ID取得
    def find_or_create_delivery_model_ids(model_names, karaoke_type)
      return [] if model_names.blank?
      
      # DeliveryModelManagerのキャッシュを活用
      manager = DeliveryModelManager.instance
      manager.find_or_create_ids(model_names, karaoke_type).compact
    end
  end
end