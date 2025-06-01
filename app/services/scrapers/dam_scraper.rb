# frozen_string_literal: true

module Scrapers
  # DAM楽曲情報のスクレイピングを行うクラス
  class DamScraper < BaseScraper
    # DAM楽曲ページをスクレイピング
    def scrape_song_page(dam_song)
      with_retry(on_retry: ->(_e, _count) { reset_browser_manager(timeout: 10, process_timeout: 10) }) do
        browser_manager.with_browser do |_browser|
          browser_manager.visit(dam_song.url)

          song_info = extract_song_info

          create_or_update_song(dam_song, song_info) if song_info[:title].present? && song_info[:title_reading].present? && song_info[:song_number].present?
        end
      end
    rescue StandardError => e
      Rails.logger.error("Error scraping DAM song page #{dam_song.url}: #{e.message}")
      raise
    end

    # DAM楽曲の配信機種情報を更新
    def update_delivery_models(song)
      with_retry(on_retry: ->(_e, _count) { reset_browser_manager(timeout: 10, process_timeout: 10) }) do
        browser_manager.with_browser do |_browser|
          browser_manager.visit(song.url)

          delivery_models = extract_delivery_models
          ouchikaraoke_url = extract_ouchikaraoke_url

          update_song_delivery_info(song, delivery_models, ouchikaraoke_url)
        end
      end
    rescue StandardError => e
      Rails.logger.error("Error updating DAM delivery models for song #{song.id}: #{e.message}")
      raise
    end

    private

    def load_selectors
      yaml_path = Rails.root.join('config/selectors/dam.yml')
      @selectors = YAML.load_file(yaml_path)['selectors']
    end

    def karaoke_type
      "DAM"
    end

    def extract_song_info
      {
        title: browser_manager.find(@selectors['song_detail']['title'])&.inner_text,
        title_reading: clean_title_reading(browser_manager.find(@selectors['song_detail']['title_reading'])&.inner_text),
        song_number: browser_manager.find(@selectors['song_detail']['song_number'])&.inner_text
      }
    end

    def clean_title_reading(reading)
      reading&.gsub(/[\[\] ]/, "")
    end

    def create_or_update_song(dam_song, song_info)
      song = Song.find_or_create_by!(
        karaoke_type: "DAM",
        song_number: song_info[:song_number],
        url: dam_song.url
      ) do |s|
        s.title = song_info[:title]
        s.title_reading = song_info[:title_reading]
        s.display_artist = dam_song.display_artist
      end

      song.update!(
        title: song_info[:title],
        title_reading: song_info[:title_reading],
        display_artist: dam_song.display_artist
      )

      delivery_models = extract_delivery_models
      ouchikaraoke_url = extract_ouchikaraoke_url

      update_song_delivery_info(song, delivery_models, ouchikaraoke_url)
    end

    def extract_delivery_models
      models = []

      # 最新機種
      latest_model = browser_manager.find(@selectors['song_detail']['latest_model'])
      models << latest_model.inner_text if latest_model

      # その他の機種
      browser_manager.find_all(@selectors['song_detail']['model_list']).each do |model|
        models << model.inner_text
      end

      models
    end

    def extract_ouchikaraoke_url
      ouchikaraoke_tag = browser_manager.find(@selectors['song_detail']['ouchikaraoke'])
      ouchikaraoke_tag&.attribute('href').present? ? ouchikaraoke_tag.property('href') : nil
    end

    def update_song_delivery_info(song, delivery_models, ouchikaraoke_url)
      # おうちカラオケがある場合は機種リストに追加
      delivery_models.push("カラオケ@DAM") if ouchikaraoke_url.present?

      # 配信機種IDの取得（存在しない機種は作成）
      kdm = find_or_create_delivery_model_ids(delivery_models.compact, "DAM")

      song.karaoke_delivery_model_ids = kdm if kdm.present?

      # おうちカラオケ情報の更新
      update_ouchikaraoke_info(song, ouchikaraoke_url)
    end

    def update_ouchikaraoke_info(song, ouchikaraoke_url)
      if ouchikaraoke_url.present?
        if song.song_with_dam_ouchikaraoke.blank?
          song.create_song_with_dam_ouchikaraoke(url: ouchikaraoke_url)
        elsif song.song_with_dam_ouchikaraoke.url != ouchikaraoke_url
          song.song_with_dam_ouchikaraoke.update!(url: ouchikaraoke_url)
        end
      elsif song.song_with_dam_ouchikaraoke.present?
        song.song_with_dam_ouchikaraoke.destroy!
      end
    end
  end
end
