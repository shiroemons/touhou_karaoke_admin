# frozen_string_literal: true

module Scrapers
  # JOYSOUND楽曲情報のスクレイピングを行うクラス
  class JoysoundScraper < BaseScraper
    KNOWN_DELIVERY_MODEL_NAMES = [
      'EnjoyPortable',
      'EnjoyStage',
      'HyperJoy V2',
      'CelebJoyHearts',
      'HyperJoy Wave',
      'JEWEL',
      'CROSSO',
      'スマホサービス',
      '家庭用カラオケ'
    ].freeze

    JOYSOUND_DELIVERY_MODEL_NAME_PATTERN = /\A(?:JOYSOUND\s+(?:[A-Za-z0-9]+\s*)+|JOYSOUND\s+響(?:Ⅱ|II|2)?)\z/

    DELIVERY_MODEL_NOTE_PATTERNS = [
      /\A※/,
      /採点ランキングを見る/,
      /全国採点/,
      /分析採点/,
      /うたスキ動画/,
      /スピードコントロール/,
      /キーコントロール/,
      /ご利用いただけません/,
      /通信環境/,
      /店舗検索結果/,
      /歌唱可能/,
      /主に.+モデル/
    ].freeze

    DELIVERY_MODEL_MORE_BUTTON_SELECTOR = '#song-distribution [data-testid="card-information"] button'

    # JOYSOUNDの楽曲ページをスクレイピング
    def scrape_song_page(url)
      with_retry do
        browser_manager.with_browser do |_browser|
          browser_manager.clear_network_traffic
          browser_manager.visit(url)

          composer = song_information["作曲"]

          scrape_artist_and_songs if should_scrape?(composer, url)
        end
      end
    rescue StandardError => e
      Admin::OperationLogger.log(level: :error, event: :external_fetch, action: :error, resource: :song, url:, karaoke_type:, error: e.message)
      raise
    end

    # JOYSOUNDミュージックポスト楽曲のスクレイピング
    def scrape_music_post_page(joysound_music_post)
      return if joysound_music_post.joysound_url.blank?

      with_retry(on_retry: ->(_e, _count) { reset_browser_manager(timeout: 30) }) do
        browser_manager.with_browser do |_browser|
          browser_manager.clear_network_traffic
          browser_manager.visit(joysound_music_post.joysound_url)
          sleep(1.0) # 描画待ち

          if missing_page?
            handle_missing_page(browser_manager.current_url, joysound_music_post)
          else
            scrape_music_post_content(joysound_music_post)
          end
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      error_details = if e.record.respond_to?(:errors)
                        e.record.errors.full_messages.join(", ")
                      else
                        e.message
                      end
      Admin::OperationLogger.log(
        level: :error,
        event: :external_fetch,
        action: :error,
        resource: :joysound_music_post,
        id: joysound_music_post.id,
        error: error_details,
        record: e.record.inspect,
        validation_errors: (e.record.errors.details if e.record.respond_to?(:errors))
      )
      raise
    rescue StandardError => e
      Admin::OperationLogger.log(level: :error, event: :external_fetch, action: :error, resource: :joysound_music_post, id: joysound_music_post.id, error: e.message, backtrace: e.backtrace.first(5).join("\n"))
      raise
    end

    private

    def load_selectors
      yaml_path = Rails.root.join('config/selectors/joysound.yml')
      @selectors = YAML.load_file(yaml_path)['selectors']
    end

    def karaoke_type
      "JOYSOUND"
    end

    def should_scrape?(composer, url)
      composer.in?(Constants::Karaoke::PERMITTED_COMPOSERS) || Constants::Karaoke::JOYSOUND_ALLOWLIST.include?(url)
    end

    def scrape_artist_and_songs
      info = song_information
      artist_el = browser_manager.find(@selectors['song_detail']['artist'])
      artist_name = info.fetch("歌手名")
      artist_url = absolute_joysound_url(artist_el&.attribute("href").to_s)

      display_artist = DisplayArtist.find_or_create_by!(
        name: artist_name,
        karaoke_type: "JOYSOUND",
        url: artist_url
      )

      expand_delivery_model_sections

      browser_manager.find_all(@selectors['song_detail']['songs']).each do |song_el|
        create_song_from_element(song_el, display_artist, browser_manager.current_url)
      end
    end

    def create_song_from_element(element, display_artist, page_url)
      title = element.at_css(@selectors['song_detail']['song_title'])&.inner_text&.strip
      song_number = element.inner_text[/曲番号:\s*([0-9]+)/, 1].to_s
      return if title.blank?

      delivery_models = extract_delivery_models(element)
      kdm = find_or_create_delivery_model_ids(delivery_models, "JOYSOUND")

      song = Song.find_or_create_by!(
        title:,
        display_artist:,
        song_number:,
        karaoke_type: "JOYSOUND",
        url: page_url
      )

      # karaoke_delivery_model_idsの更新を安全に行う
      update_delivery_models(song, kdm)
    end

    def extract_delivery_models(element)
      element.css(@selectors['song_detail']['platform_item'])
             .filter_map { |li| normalize_delivery_model_name(li.inner_text) }
             .uniq
    end

    def normalize_delivery_model_name(text)
      name = text.to_s.squish
      name = name.split(/※|\.{3}|…/, 2).first.to_s.squish

      return if name.blank?
      return if DELIVERY_MODEL_NOTE_PATTERNS.any? { |pattern| name.match?(pattern) }

      name if joysound_delivery_model_name?(name)
    end

    def joysound_delivery_model_name?(name)
      KNOWN_DELIVERY_MODEL_NAMES.include?(name) || name.match?(JOYSOUND_DELIVERY_MODEL_NAME_PATTERN)
    end

    def expand_delivery_model_sections
      browser_manager.find_all(DELIVERY_MODEL_MORE_BUTTON_SELECTOR).each do |button|
        next unless button.inner_text.to_s.squish == "その他"

        button.focus.click
      end
    end

    def song_information
      browser_manager.find_all(@selectors['song_detail']['information_rows']).each_with_object({}) do |row, result|
        key = row.at_css("th")&.inner_text&.strip
        value = row.at_css("td")&.inner_text&.strip
        result[key] = value if key.present?
      end
    end

    def absolute_joysound_url(path)
      return "" if path.blank?

      URI.join(Constants::Karaoke::Joysound::BASE_URL, path).to_s
    end

    def handle_missing_page(url, joysound_music_post)
      song = Song.find_by(karaoke_type: "JOYSOUND(うたスキ)", url:)
      return unless song

      song.destroy!
      joysound_music_post.destroy!
    end

    def scrape_music_post_content(joysound_music_post)
      info = song_information
      artist_el = browser_manager.find(@selectors['song_detail']['artist'])
      artist_name = info.fetch("歌手名")
      artist_url = absolute_joysound_url(artist_el&.attribute("href").to_s)

      display_artist = DisplayArtist.find_or_create_by!(
        name: artist_name,
        karaoke_type: "JOYSOUND(うたスキ)",
        url: artist_url
      )

      expand_delivery_model_sections

      browser_manager.find_all(@selectors['song_detail']['songs']).each do |block|
        create_music_post_song(block, display_artist, joysound_music_post)
      end
    end

    def create_music_post_song(block, display_artist, joysound_music_post)
      title = block.at_css(@selectors['song_detail']['song_title'])&.inner_text&.strip
      return if title.blank?

      delivery_models = extract_delivery_models(block)
      kdm = find_or_create_delivery_model_ids(delivery_models, "JOYSOUND(うたスキ)")

      song = Song.find_or_create_by!(
        title:,
        display_artist:,
        karaoke_type: "JOYSOUND(うたスキ)",
        url: browser_manager.current_url
      )

      # karaoke_delivery_model_idsの更新を安全に行う
      update_delivery_models(song, kdm)
      update_song_with_joysound_utasuki(song, joysound_music_post)
    end

    def missing_page?
      text = browser_manager.find(@selectors['song_detail']['error'])&.inner_text.to_s
      text.include?("このページは存在しません。") || text.include?("ページが見つかりません")
    end

    def update_song_with_joysound_utasuki(song, joysound_music_post)
      if song.song_with_joysound_utasuki.blank?
        song.create_song_with_joysound_utasuki(
          delivery_deadline_date: joysound_music_post.delivery_deadline_on,
          url: joysound_music_post.url
        )
      elsif song.song_with_joysound_utasuki.delivery_deadline_date != joysound_music_post.delivery_deadline_on
        song.song_with_joysound_utasuki.update!(
          delivery_deadline_date: joysound_music_post.delivery_deadline_on
        )
      end
    end

    def update_delivery_models(song, new_delivery_model_ids)
      ActiveRecord::Base.transaction do
        # 現在の関連を取得
        current_ids = song.karaoke_delivery_model_ids

        # 追加すべきIDと削除すべきIDを計算
        ids_to_add = new_delivery_model_ids - current_ids
        ids_to_remove = current_ids - new_delivery_model_ids

        # 削除処理
        if ids_to_remove.any?
          song.songs_karaoke_delivery_models
              .where(karaoke_delivery_model_id: ids_to_remove)
              .destroy_all
        end

        # 追加処理（重複チェック付き）
        ids_to_add.each do |model_id|
          song.songs_karaoke_delivery_models.create!(karaoke_delivery_model_id: model_id) unless song.songs_karaoke_delivery_models.exists?(karaoke_delivery_model_id: model_id)
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      Admin::OperationLogger.log(level: :error, event: :db_update, action: :error, resource: :song, id: song.id, error: e.message, attempted_delivery_model_ids: new_delivery_model_ids, current_delivery_model_ids: song.karaoke_delivery_model_ids)
      # エラーが発生しても処理を継続（ROLLBACKを防ぐ）
    end
  end
end
