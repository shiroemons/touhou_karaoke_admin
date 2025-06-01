# frozen_string_literal: true

module Scrapers
  # スクレイパーの基底クラス
  class BaseScraper
    include Retryable

    attr_reader :browser_manager, :delivery_models

    def initialize
      @browser_manager = BrowserManager.new
      load_delivery_models
    end

    protected

    # 配信機種のキャッシュを読み込み
    def load_delivery_models
      @delivery_models = KaraokeDeliveryModel.pluck(:name, :id).to_h
    end

    # ブラウザマネージャーをリセット（エラー時の復旧用）
    def reset_browser_manager(custom_options = {})
      @browser_manager = BrowserManager.new(custom_options)
    end

    # 配信機種IDの配列を取得
    def get_delivery_model_ids(model_names)
      model_names.filter_map { |name| @delivery_models[name] }
    end

    # 新しい配信機種を作成してIDを返す
    def create_delivery_model(name, karaoke_type)
      model = KaraokeDeliveryModel.create!(name:, karaoke_type:)
      @delivery_models[name] = model.id
      Rails.logger.info("Created new KaraokeDeliveryModel: #{name}")
      model.id
    end
  end
end
