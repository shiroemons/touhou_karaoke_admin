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

    get_id_without_refresh(name, karaoke_type)
  end

  # 複数の配信機種名からIDの配列を取得
  def get_ids(names, karaoke_type = nil)
    ensure_cache_fresh

    names.filter_map { |name| get_id(name, karaoke_type) }
  end

  # 配信機種を取得または作成してIDを返す（バリデーション強化版）
  def find_or_create_id(name, karaoke_type)
    # 名前を正規化
    validator = DeliveryModelValidator.new
    normalized_name = validator.normalize_name(name)

    return nil if normalized_name.blank?

    # まずキャッシュから検索（正規化された名前で）
    id = get_id(normalized_name, karaoke_type)
    return id if id

    # キャッシュになければデータベースから再度検索（他プロセスが作成した可能性）
    @mutex.synchronize do
      # 再度キャッシュを確認（ダブルチェックロッキング）
      id = get_id_without_refresh(normalized_name, karaoke_type)
      return id if id

      # バリデーターを使用して安全に取得または作成
      model = validator.find_or_create_safely(normalized_name, karaoke_type)

      if model
        @cache[[normalized_name, karaoke_type]] = model.id
        # 元の名前もキャッシュに追加（正規化前の名前での検索を高速化）
        @cache[[name, karaoke_type]] = model.id if name != normalized_name
        model.id
      else
        Rails.logger.error("Failed to create KaraokeDeliveryModel: #{normalized_name} (#{karaoke_type})")
        nil
      end
    end
  end

  # 複数の配信機種を一括で取得または作成
  def find_or_create_ids(names, karaoke_type)
    names.map { |name| find_or_create_id(name, karaoke_type) }
  end

  # 配信機種を取得または作成（OptimizedJoysoundScraperで使用）
  def find_or_create_by_name_and_type(name, karaoke_type)
    return nil if name.blank? || karaoke_type.blank?

    model_id = find_or_create_id(name, karaoke_type)
    return nil if model_id.nil?

    # キャッシュから検索
    cached_model = @cache.find { |key, id| key == [name, karaoke_type] && id == model_id }
    if cached_model
      # モデルオブジェクトを返すため、IDからモデルを取得
      KaraokeDeliveryModel.find(model_id)
    end
  rescue ActiveRecord::RecordNotFound
    nil
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

  # キャッシュリフレッシュなしでIDを取得
  def get_id_without_refresh(name, karaoke_type)
    if karaoke_type.nil?
      @cache.find { |key, _| key.first == name }&.last
    else
      @cache[[name, karaoke_type]]
    end
  end

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
