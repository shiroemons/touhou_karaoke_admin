# frozen_string_literal: true

module Scrapers
  # JOYSOUND楽曲情報のスクレイピングを行うクラス
  class JoysoundScraper < BaseScraper
    # JOYSOUNDの楽曲ページをスクレイピング
    def scrape_song_page(url)
      with_retry do
        browser_manager.with_browser do |_browser|
          browser_manager.clear_network_traffic
          browser_manager.visit(url)

          composer = browser_manager.find(@selectors['song_detail']['composer'])&.inner_text

          scrape_artist_and_songs(url) if should_scrape?(composer, url)
        end
      end
    rescue StandardError => e
      Rails.logger.error("Error scraping JOYSOUND song page #{url}: #{e.message}")
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

          error_text = browser_manager.find(@selectors['song_detail']['error'])&.inner_text
          if error_text == "このページは存在しません。"
            handle_missing_page(browser_manager.current_url, joysound_music_post)
          else
            scrape_music_post_content(joysound_music_post)
          end
        end
      end
    rescue StandardError => e
      Rails.logger.error("Error scraping JOYSOUND music post #{joysound_music_post.id}: #{e.message}")
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

    def scrape_artist_and_songs(url)
      artist_el = browser_manager.find(@selectors['song_detail']['artist'])
      artist_name = artist_el.inner_text
      artist_url = artist_el.property("href")

      display_artist = DisplayArtist.find_or_create_by!(
        name: artist_name,
        karaoke_type: "JOYSOUND",
        url: artist_url
      )

      browser_manager.find_all(@selectors['song_detail']['songs']).each do |song_el|
        create_song_from_element(song_el, display_artist, url)
      end
    end

    def create_song_from_element(element, display_artist, page_url)
      title = element.at_css(@selectors['song_detail']['song_title']).inner_text
      song_number = element.at_css(@selectors['song_detail']['song_number']).inner_text

      delivery_models = extract_delivery_models(element)
      kdm = find_or_create_delivery_model_ids(delivery_models, "JOYSOUND")

      song = Song.find_or_create_by!(
        title:,
        display_artist:,
        song_number:,
        karaoke_type: "JOYSOUND",
        url: page_url
      )
      song.karaoke_delivery_model_ids = kdm
    end

    def extract_delivery_models(element)
      models = []
      element.css(@selectors['song_detail']['karaoke_platform']).each do |ul|
        ul.css(@selectors['song_detail']['platform_item']).each do |li|
          models.push(li.at_css(@selectors['song_detail']['platform_image']).attribute("alt"))
        end
      end
      models
    end

    def handle_missing_page(url, joysound_music_post)
      song = Song.find_by(karaoke_type: "JOYSOUND(うたスキ)", url:)
      return unless song

      song.destroy!
      joysound_music_post.destroy!
    end

    def scrape_music_post_content(joysound_music_post)
      artist_el = browser_manager.find(@selectors['song_detail']['artist'])
      artist_name = artist_el.inner_text
      artist_url = artist_el.property("href")

      display_artist = DisplayArtist.find_or_create_by!(
        name: artist_name,
        karaoke_type: "JOYSOUND(うたスキ)",
        url: artist_url
      )

      song_blocks = "#jp-cmp-karaoke-kyokupro > div.jp-cmp-kyokupuro-block"
      browser_manager.find_all(song_blocks).each do |block|
        create_music_post_song(block, display_artist, joysound_music_post)
      end
    end

    def create_music_post_song(block, display_artist, joysound_music_post)
      title = block.at_css("div.jp-cmp-karaoke-details > h4").inner_text

      delivery_models = extract_delivery_models(block)
      kdm = find_or_create_delivery_model_ids(delivery_models, "JOYSOUND(うたスキ)")

      song = Song.find_or_create_by!(
        title:,
        display_artist:,
        karaoke_type: "JOYSOUND(うたスキ)",
        url: browser_manager.current_url
      )
      song.karaoke_delivery_model_ids = kdm

      update_song_with_joysound_utasuki(song, joysound_music_post)
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
  end
end
