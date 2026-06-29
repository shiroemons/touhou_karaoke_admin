# frozen_string_literal: true

# 配信機種の作成・更新時のバリデーションを強化するサービスクラス
#
# 機能:
#   1. 配信機種名の正規化（空白の除去、全角/半角統一など）
#   2. 重複チェックの強化
#   3. 作成前の事前検証
#
# 使用例:
#   validator = DeliveryModelValidator.new
#
#   # 正規化
#   normalized_name = validator.normalize_name("　JOYSOUND MAX GO　")
#   # => "JOYSOUND MAX GO"
#
#   # 重複チェック
#   if validator.duplicate_exists?("JOYSOUND MAX GO", "JOYSOUND")
#     puts "重複があります"
#   end
#
#   # 安全な作成
#   model = validator.find_or_create_safely("JOYSOUND MAX GO", "JOYSOUND")
class DeliveryModelValidator
  # 配信機種名を正規化
  def normalize_name(name)
    return nil if name.blank?

    normalized = name.to_s.strip

    # 全角スペースを半角スペースに変換
    normalized = normalized.tr('　', ' ')

    # 連続する空白を単一の空白に変換
    normalized = normalized.gsub(/\s+/, ' ')

    # 前後の空白を除去
    normalized.strip
  end

  # 重複チェック（正規化も含む）
  def duplicate_exists?(name, karaoke_type)
    normalized_name = normalize_name(name)
    return false if normalized_name.blank?

    KaraokeDeliveryModel.exists?(name: normalized_name, karaoke_type:)
  end

  # 安全な作成（重複チェック + 正規化）
  def find_or_create_safely(name, karaoke_type)
    normalized_name = normalize_name(name)

    if normalized_name.blank?
      Admin::OperationLogger.log(level: :warn, event: :db_update, action: :skip, resource: :karaoke_delivery_model, name: name.inspect, reason: "blank_name")
      return nil
    end

    # 既存レコードを検索
    existing_model = KaraokeDeliveryModel.find_by(name: normalized_name, karaoke_type:)
    return existing_model if existing_model

    # 作成前の最終チェック
    if duplicate_exists?(normalized_name, karaoke_type)
      Admin::OperationLogger.log(level: :info, event: :db_update, action: :skip, resource: :karaoke_delivery_model, name: normalized_name, karaoke_type:, reason: "duplicate")
      return KaraokeDeliveryModel.find_by(name: normalized_name, karaoke_type:)
    end

    # 新規作成
    begin
      model = KaraokeDeliveryModel.create!(name: normalized_name, karaoke_type:)
      Admin::OperationLogger.log(level: :info, event: :db_update, action: :create, resource: :karaoke_delivery_model, id: model.id, name: normalized_name, karaoke_type:)
      model
    rescue ActiveRecord::RecordNotUnique => e
      Admin::OperationLogger.log(level: :warn, event: :db_update, action: :retry, resource: :karaoke_delivery_model, name: normalized_name, karaoke_type:, error: e.message)
      # 他のプロセスが同時に作成した場合
      KaraokeDeliveryModel.find_by!(name: normalized_name, karaoke_type:)
    rescue ActiveRecord::RecordInvalid => e
      Admin::OperationLogger.log(level: :error, event: :db_update, action: :error, resource: :karaoke_delivery_model, name: normalized_name, karaoke_type:, error: e.message)
      nil
    end
  end

  # バッチでの安全な作成
  def find_or_create_safely_batch(names, karaoke_type)
    names.filter_map { |name| find_or_create_safely(name, karaoke_type) }
  end

  # 既存レコードの正規化（データクリーンアップ用）
  def normalize_existing_records
    updated_count = 0

    KaraokeDeliveryModel.find_each do |model|
      normalized_name = normalize_name(model.name)

      next if normalized_name == model.name

      # 正規化後の名前で重複がないかチェック
      if KaraokeDeliveryModel.where(name: normalized_name, karaoke_type: model.karaoke_type)
                             .where.not(id: model.id)
                             .exists?
        Admin::OperationLogger.log(level: :warn, event: :db_update, action: :skip, resource: :karaoke_delivery_model, id: model.id, name: model.name, normalized_name:, reason: "duplicate")
        next
      end

      begin
        original_name = model.name
        model.update!(name: normalized_name)
        updated_count += 1
        Admin::OperationLogger.log(level: :info, event: :db_update, action: :update, resource: :karaoke_delivery_model, id: model.id, name: original_name, normalized_name:)
      rescue ActiveRecord::RecordInvalid => e
        Admin::OperationLogger.log(level: :error, event: :db_update, action: :error, resource: :karaoke_delivery_model, id: model.id, name: model.name, normalized_name:, error: e.message)
      end
    end

    Rails.logger.info("DeliveryModelValidator: Normalized #{updated_count} records")
    updated_count
  end
end
