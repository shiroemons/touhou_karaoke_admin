# frozen_string_literal: true

# 配信機種の管理を一元化するサービスクラス
class DeliveryModelManager
  include Singleton

  # キャッシュの有効期限（分）
  CACHE_TTL = 60

  def initialize
    @cache = {}
    @cache_expires_at = nil
    @mutex = Mutex.new
  end

  # 配信機種名からIDを取得（キャッシュ利用）
  def get_id(name, karaoke_type = nil)
    ensure_cache_fresh

    # karaoke_typeが指定されていない場合は名前のみで検索
    if karaoke_type.nil?
      @cache.find { |key, _| key.first == name }&.last
    else
      @cache[[name, karaoke_type]]
    end
  end

  # 複数の配信機種名からIDの配列を取得
  def get_ids(names, karaoke_type = nil)
    ensure_cache_fresh

    names.filter_map { |name| get_id(name, karaoke_type) }
  end

  # 配信機種を取得または作成してIDを返す
  def find_or_create_id(name, karaoke_type)
    # まずキャッシュから検索
    id = get_id(name, karaoke_type)
    return id if id

    # キャッシュになければデータベースから再度検索（他プロセスが作成した可能性）
    @mutex.synchronize do
      # 再度キャッシュを確認（ダブルチェックロッキング）
      id = get_id(name, karaoke_type)
      return id if id

      # データベースから検索
      model = KaraokeDeliveryModel.find_by(name:, karaoke_type:)

      if model
        # 見つかったらキャッシュに追加
        @cache[[name, karaoke_type]] = model.id
        return model.id
      end

      # 見つからなければ作成
      begin
        model = KaraokeDeliveryModel.create!(name:, karaoke_type:)
        Rails.logger.info("Created new KaraokeDeliveryModel: #{name} (#{karaoke_type})")
        @cache[[name, karaoke_type]] = model.id
        model.id
      rescue ActiveRecord::RecordNotUnique
        # 他のプロセスが同時に作成した場合
        model = KaraokeDeliveryModel.find_by!(name:, karaoke_type:)
        @cache[[name, karaoke_type]] = model.id
        model.id
      end
    end
  end

  # 複数の配信機種を一括で取得または作成
  def find_or_create_ids(names, karaoke_type)
    names.map { |name| find_or_create_id(name, karaoke_type) }
  end

  # キャッシュをリフレッシュ
  def refresh_cache
    @mutex.synchronize do
      load_cache
    end
  end

  # キャッシュをクリア
  def clear_cache
    @mutex.synchronize do
      @cache.clear
      @cache_expires_at = nil
    end
  end

  private

  # キャッシュが有効か確認し、必要なら再読み込み
  def ensure_cache_fresh
    @mutex.synchronize do
      load_cache if @cache_expires_at.nil? || Time.current > @cache_expires_at
    end
  end

  # データベースからキャッシュを読み込み
  def load_cache
    @cache = KaraokeDeliveryModel
             .pluck(:name, :karaoke_type, :id)
             .each_with_object({}) do |(name, karaoke_type, id), hash|
      hash[[name, karaoke_type]] = id
    end
    @cache_expires_at = Time.current + CACHE_TTL.minutes

    Rails.logger.debug { "DeliveryModelManager: Loaded #{@cache.size} delivery models into cache" }
  end
end
