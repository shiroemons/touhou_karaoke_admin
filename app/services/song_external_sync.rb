class SongExternalSync
  class << self
    def fetch_joysound_song(url = nil)
      return if url.blank?

      scraper = Scrapers::JoysoundScraper.new
      scraper.scrape_song_page(url)
    end

    def fetch_joysound_songs(progress: nil)
      joysound_songs = JoysoundSong.all
      existing_joysound_keys = Song.where(karaoke_type: "JOYSOUND").pluck(:title, :url).to_set

      Song.process_with_progress(
        joysound_songs,
        label: "JOYSOUND楽曲",
        progress:,
        progress_options: { status: "JOYSOUND楽曲取得中", label: "JOYSOUND楽曲詳細を取得しています" },
        worker_factory: -> { Scrapers::JoysoundScraper.new(browser_manager: BrowserManager.new(persistent: true)) },
        worker_teardown: ->(w) { w.shutdown },
        continue_on_error: true
      ) do |record, scraper|
        title = record.display_title.split("／").first
        scraper.scrape_song_page(record.url) unless existing_joysound_keys.include?([title, record.url])
      end

      existing_joysound_urls = Song.where(karaoke_type: "JOYSOUND").pluck(:url).to_set
      allowlist_scraper = Scrapers::JoysoundScraper.new

      Constants::Karaoke::JOYSOUND_ALLOWLIST.each.with_index(1) do |url, index|
        next if existing_joysound_urls.include?(url)

        Admin::ProgressReporter.report(
          progress:,
          percentage: 97,
          status: "JOYSOUND楽曲取得中",
          label: "JOYSOUND許可リストを確認しています",
          detail: "許可リスト: #{index}/#{Constants::Karaoke::JOYSOUND_ALLOWLIST.count}件",
          current: index,
          total: Constants::Karaoke::JOYSOUND_ALLOWLIST.count
        )
        allowlist_scraper.scrape_song_page(url)
      end
    end

    def fetch_joysound_music_post_song
      prioritized_posts = JoysoundMusicPostPrioritizer.call

      Song.process_with_progress(
        prioritized_posts,
        label: "ミュージックポスト",
        worker_factory: -> { Scrapers::JoysoundScraper.new(browser_manager: BrowserManager.new(persistent: true)) },
        worker_teardown: ->(w) { w.shutdown },
        continue_on_error: true
      ) do |record, scraper|
        scraper.scrape_music_post_page(record)
      end
    end

    def prioritized_joysound_music_posts
      JoysoundMusicPostPrioritizer.call
    end

    # DEPRECATED: 実運用は JoysoundMusicPostManager 経由。将来削除候補。
    def refresh_joysound_music_post_song
      browser_manager = BrowserManager.new
      total_count = Song.music_post.count

      browser_manager.with_browser do
        Song.music_post.each.with_index(1) do |song, index|
          Rails.logger.debug { "#{index}/#{total_count}: #{((index / total_count.to_f) * 100).floor}% #{song.title}" }
          browser_manager.visit(song.url)
          sleep(1.0)

          error_selector = "#jp-cmp-main > div > h1.jp-cmp-h1-error"
          error = browser_manager.find(error_selector)&.inner_text
          if error == "このページは存在しません。"
            record = Song.find_by(karaoke_type: "JOYSOUND(うたスキ)", url: browser_manager.current_url)
            record&.destroy!
          end
        end
      end
    end

    def fetch_dam_songs(progress: nil)
      dam_songs = DamSong.order(created_at: :desc)
      existing_dam_urls = Song.where(karaoke_type: "DAM").pluck(:url).to_set

      Song.process_with_progress(
        dam_songs,
        label: "DAM楽曲",
        progress:,
        progress_options: { status: "DAM楽曲取得中", label: "DAM楽曲詳細を取得しています" },
        worker_factory: -> { Scrapers::DamScraper.new(browser_manager: BrowserManager.new(persistent: true)) },
        worker_teardown: ->(w) { w.shutdown },
        continue_on_error: true
      ) do |record, scraper|
        next if existing_dam_urls.include?(record.url)

        scraper.scrape_song_page(record)
      end
    end

    def update_dam_delivery_models(progress: nil)
      dam_songs = Song.dam.includes(:karaoke_delivery_models)

      Song.process_with_progress(
        dam_songs,
        label: "DAM配信機種更新",
        progress:,
        progress_options: { status: "DAM配信機種更新中", label: "DAM配信機種を更新しています" },
        worker_factory: -> { Scrapers::DamScraper.new(browser_manager: BrowserManager.new(persistent: true)) },
        worker_teardown: ->(w) { w.shutdown }
      ) do |song, scraper|
        scraper.update_delivery_models(song)
      end
    end

    # DEPRECATED: 実運用は JoysoundMusicPostManager 経由。将来削除候補。
    def update_joysound_music_post_delivery_deadline_dates
      music_post_songs = Song.music_post.includes(:song_with_joysound_utasuki)
                             .where.not(song_with_joysound_utasukis: { id: nil })
      deadline_lookup = JoysoundMusicPost.pluck(:url, :delivery_deadline_on).to_h

      total_count = music_post_songs.count
      updated_count = 0

      music_post_songs.each.with_index(1) do |song, index|
        Rails.logger.debug { "#{index}/#{total_count}: #{((index / total_count.to_f) * 100).floor}% #{song.title}" }

        deadline_on = deadline_lookup[song.song_with_joysound_utasuki.url]

        if deadline_on && song.song_with_joysound_utasuki.delivery_deadline_date != deadline_on
          song.song_with_joysound_utasuki.update!(delivery_deadline_date: deadline_on)
          updated_count += 1
          Rails.logger.debug { "Updated delivery_deadline_date for: #{song.title}" }
        end
      end

      Rails.logger.info("Updated #{updated_count} songs out of #{total_count} total music post songs")
    end
  end
end
