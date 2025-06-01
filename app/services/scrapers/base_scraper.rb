require 'yaml'

module Scrapers
  class BaseScraper
    include Retryable

    def initialize
      @browser_manager = BrowserManager.new
      @delivery_model_manager = DeliveryModelManager.new
      load_selectors
    end

    protected

    attr_reader :browser_manager

    def with_retry(retries: 3, retry_logger: Rails.logger, &)
      super
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

      model_names.each do |model_name|
        delivery_model = @delivery_model_manager.find_or_create(model_name, karaoke_type)
        song.karaoke_delivery_models << delivery_model unless song.karaoke_delivery_models.include?(delivery_model)
      end
    end

    def create_sub_model(_song, _attrs)
      # 子クラスでオーバーライドして実装
    end

    def karaoke_type
      raise NotImplementedError, "#{self.class} must implement #karaoke_type"
    end
  end
end
