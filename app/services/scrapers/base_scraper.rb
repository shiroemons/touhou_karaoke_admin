# frozen_string_literal: true

module Scrapers
  # スクレイパーの基底クラス
  class BaseScraper
    include Retryable

    attr_reader :browser_manager

    def initialize
      @browser_manager = BrowserManager.new
      @delivery_model_manager = DeliveryModelManager.instance
    end

    protected

    # ブラウザマネージャーをリセット（エラー時の復旧用）
    def reset_browser_manager(custom_options = {})
      @browser_manager = BrowserManager.new(custom_options)
    end

    # 配信機種IDの配列を取得
    def get_delivery_model_ids(model_names, karaoke_type = nil)
      @delivery_model_manager.get_ids(model_names, karaoke_type)
    end

    # 配信機種を取得または作成してIDを返す
    def find_or_create_delivery_model_id(name, karaoke_type)
      @delivery_model_manager.find_or_create_id(name, karaoke_type)
    end

    # 複数の配信機種を一括で取得または作成
    def find_or_create_delivery_model_ids(names, karaoke_type)
      @delivery_model_manager.find_or_create_ids(names, karaoke_type)
    end
  end
end
