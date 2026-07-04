require 'yaml'

module Scrapers
  class BaseScraper
    include Retryable

    # 永続ブラウザを再生成するまでに許容する処理件数（メモリ・キャッシュ肥大対策）
    SCRAPING_BROWSER_MAX_USES = ENV.fetch('SCRAPING_BROWSER_MAX_USES', 50).to_i

    def initialize(browser_manager: BrowserManager.new, delivery_model_manager: DeliveryModelManager.instance)
      @browser_manager = browser_manager
      @delivery_model_manager = delivery_model_manager
      @browser_use_count = 0
      load_selectors
    end

    # 永続ブラウザを終了する（ワーカープールの後始末用）
    def shutdown
      @browser_manager&.close
    end

    protected

    attr_reader :browser_manager

    def with_retry(max_retries: 3, errors: RETRYABLE_ERRORS, on_retry: nil, &)
      super
    end

    def reset_browser_manager(timeout: 10, process_timeout: 10)
      @browser_manager = BrowserManager.new({ timeout:, process_timeout: }, persistent: @browser_manager&.persistent?)
    end

    # 処理件数をカウントし、上限に達したらChromeプロセスごと作り直す
    # 永続ブラウザが再利用されている場合にのみ意味を持つ（非永続モードでは常に安全なno-op）
    # 呼び出し配線（各scrapeメソッド末尾など）は利用側で行う
    def track_browser_use
      @browser_manager.reset_session
      @browser_use_count += 1

      return unless @browser_use_count >= SCRAPING_BROWSER_MAX_USES

      @browser_manager.restart
      @browser_use_count = 0
    end

    def save_song(song_attrs)
      display_artist = ensure_display_artist(song_attrs[:artist_name], song_attrs[:artist_url])

      song = Song.find_or_initialize_by(
        url: song_attrs[:url],
        karaoke_type: song_attrs[:karaoke_type]
      )

      song.assign_attributes(
        title: song_attrs[:title],
        title_reading: song_attrs[:title_reading],
        song_number: song_attrs[:song_number],
        display_artist:
      )

      song.save!

      # 配信機種情報を更新
      update_delivery_models(song, song_attrs[:delivery_models]) if song_attrs[:delivery_models]

      # サブモデルの作成
      create_sub_model(song, song_attrs[:sub_model_attrs]) if song_attrs[:sub_model_attrs]

      song
    end

    private

    def load_selectors
      # 子クラスでオーバーライドして実装
    end

    def ensure_display_artist(name, url)
      DisplayArtist.find_or_create_by!(
        karaoke_type:,
        url:
      ) do |da|
        da.name = name
      end
    end

    def update_delivery_models(song, model_names)
      return if model_names.blank?

      delivery_model_ids = @delivery_model_manager.find_or_create_ids(model_names, karaoke_type)
      song.karaoke_delivery_model_ids = (song.karaoke_delivery_model_ids + delivery_model_ids).uniq
    end

    def find_or_create_delivery_model_ids(model_names, karaoke_type)
      @delivery_model_manager.find_or_create_ids(model_names, karaoke_type)
    end

    def create_sub_model(_song, _attrs)
      # 子クラスでオーバーライドして実装
    end

    def karaoke_type
      raise NotImplementedError, "#{self.class} must implement #karaoke_type"
    end
  end
end
