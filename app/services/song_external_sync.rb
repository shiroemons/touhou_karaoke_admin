class SongExternalSync
  class << self
    def fetch_joysound_song(url = nil)
      return if url.blank?

      scraper = Scrapers::JoysoundScraper.new
      scraper.scrape_song_page(url)
    end

    def fetch_joysound_songs(progress: nil)
      scraper = Scrapers::JoysoundScraper.new
      joysound_songs = JoysoundSong.all

      Song.process_with_progress(joysound_songs, label: "JOYSOUND Songs", progress:, progress_options: { status: "JOYSOUND楽曲取得中", label: "JOYSOUND楽曲詳細を取得しています" }) do |record|
        title = record.display_title.split("／").first
        scraper.scrape_song_page(record.url) unless Song.exists?(title:, url: record.url, karaoke_type: "JOYSOUND")
      end

      Constants::Karaoke::JOYSOUND_ALLOWLIST.each.with_index(1) do |url, index|
        next if Song.exists?(url:, karaoke_type: "JOYSOUND")

        progress&.call(
          percentage: 97,
          status: "JOYSOUND楽曲取得中",
          label: "JOYSOUND許可リストを確認しています",
          detail: "許可リスト: #{index}/#{Constants::Karaoke::JOYSOUND_ALLOWLIST.count}件",
          current: index,
          total: Constants::Karaoke::JOYSOUND_ALLOWLIST.count
        )
        scraper.scrape_song_page(url)
      end
    end

    def fetch_joysound_music_post_song
      scraper = Scrapers::JoysoundScraper.new
      prioritized_posts = prioritized_joysound_music_posts

      Song.process_with_progress(prioritized_posts, label: "JOYSOUND Music Posts") do |record|
        scraper.scrape_music_post_page(record)
      end
    end

    def prioritized_joysound_music_posts
      unmatched_urls = JoysoundMusicPost.pluck(:joysound_url) - Song.music_post.pluck(:url)
      unmatched_posts = JoysoundMusicPost.where(joysound_url: unmatched_urls)

      upcoming_posts = JoysoundMusicPost
                       .where(delivery_deadline_on: ...1.month.from_now)
                       .order(delivery_deadline_on: :asc)

      (unmatched_posts.to_a + upcoming_posts.to_a).uniq
    end

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
      scraper = Scrapers::DamScraper.new
      dam_songs = DamSong.order(created_at: :desc)

      Song.process_with_progress(dam_songs, label: "DAM Songs", progress:, progress_options: { status: "DAM楽曲取得中", label: "DAM楽曲詳細を取得しています" }) do |record|
        song = Song.includes(:song_with_dam_ouchikaraoke).find_by(karaoke_type: "DAM", url: record.url)
        next if song.present?

        scraper.scrape_song_page(record)
      end
    end

    def update_dam_delivery_models(progress: nil)
      scraper = Scrapers::DamScraper.new
      dam_songs = Song.dam.includes(:karaoke_delivery_models)

      Song.process_with_progress(dam_songs, label: "Update DAM Delivery Models", progress:, progress_options: { status: "DAM配信機種更新中", label: "DAM配信機種を更新しています" }) do |song|
        scraper.update_delivery_models(song)
      end
    end

    def update_joysound_music_post_delivery_deadline_dates
      music_post_songs = Song.music_post.includes(:song_with_joysound_utasuki)
                             .where.not(song_with_joysound_utasukis: { id: nil })

      total_count = music_post_songs.count
      updated_count = 0

      music_post_songs.each.with_index(1) do |song, index|
        Rails.logger.debug { "#{index}/#{total_count}: #{((index / total_count.to_f) * 100).floor}% #{song.title}" }

        music_post = JoysoundMusicPost.find_by(url: song.song_with_joysound_utasuki.url)

        if music_post && song.song_with_joysound_utasuki.delivery_deadline_date != music_post.delivery_deadline_on
          song.song_with_joysound_utasuki.update!(delivery_deadline_date: music_post.delivery_deadline_on)
          updated_count += 1
          Rails.logger.debug { "Updated delivery_deadline_date for: #{song.title}" }
        end
      end

      Rails.logger.info("Updated #{updated_count} songs out of #{total_count} total music post songs")
    end
  end
end
