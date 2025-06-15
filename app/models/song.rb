class Song < ApplicationRecord
  include AlgoliaSearchable
  include Categorizable
  include ParallelProcessor

  has_one :song_with_dam_ouchikaraoke, dependent: :destroy
  has_one :song_with_joysound_utasuki, dependent: :destroy

  has_many :songs_karaoke_delivery_models, dependent: :destroy
  has_many :karaoke_delivery_models, -> { order(order: :desc) }, through: :songs_karaoke_delivery_models, inverse_of: :songs
  has_many :songs_original_songs, dependent: :destroy
  has_many :original_songs, through: :songs_original_songs, inverse_of: :songs

  belongs_to :display_artist

  scope :missing_original_songs, -> { where.missing(:songs_original_songs) }
  scope :dam, -> { where(karaoke_type: "DAM") }
  scope :joysound, -> { where(karaoke_type: "JOYSOUND") }
  scope :music_post, -> { where(karaoke_type: "JOYSOUND(うたスキ)") }
  scope :touhou_arrange, -> { includes(:original_songs).where.not(original_songs: { original_code: "0699" }) }
  scope :youtube, -> { where.not(youtube_url: "") }
  scope :apple_music, -> { where.not(apple_music_url: "") }
  scope :youtube_music, -> { where.not(youtube_music_url: "") }
  scope :spotify, -> { where.not(spotify_url: "") }
  scope :line_music, -> { where.not(line_music_url: "") }

  def self.ransackable_attributes(_auth_object = nil)
    ["title"]
  end

  def touhou?
    return false if original_songs.blank?

    original_songs.all? { it.title != 'オリジナル' } && !original_songs.all? { it.title == 'その他' }
  end

  def self.not_set_original_song
    includes(:display_artist, :original_songs).select do |song|
      song if song.original_songs.blank?
    end
  end

  def self.fetch_joysound_song(url = nil)
    return if url.blank?

    scraper = Scrapers::JoysoundScraper.new
    scraper.scrape_song_page(url)
  end

  def self.fetch_joysound_songs
    scraper = Scrapers::JoysoundScraper.new
    joysound_songs = JoysoundSong.all

    # ParallelProcessorを使用してバッチ処理
    process_with_progress(joysound_songs, label: "JOYSOUND Songs") do |record|
      title = record.display_title.split("／").first
      scraper.scrape_song_page(record.url) unless Song.exists?(title:, url: record.url, karaoke_type: "JOYSOUND")
    end

    # 許可リストの処理
    Constants::Karaoke::JOYSOUND_ALLOWLIST.each do |url|
      next if Song.exists?(url:, karaoke_type: "JOYSOUND")

      scraper.scrape_song_page(url)
    end
  end

  def self.fetch_joysound_music_post_song
    scraper = Scrapers::JoysoundScraper.new

    # 処理対象のJoysoundMusicPostを優先度順に取得
    prioritized_posts = prioritized_joysound_music_posts

    # ParallelProcessorを使用してバッチ処理
    process_with_progress(prioritized_posts, label: "JOYSOUND Music Posts") do |record|
      scraper.scrape_music_post_page(record)
    end
  end

  def self.prioritized_joysound_music_posts
    # 差分URLの取得
    unmatched_urls = JoysoundMusicPost.pluck(:joysound_url) - Song.music_post.pluck(:url)
    unmatched_posts = JoysoundMusicPost.where(joysound_url: unmatched_urls)

    # 1ヶ月以内の配信期限のポスト
    upcoming_posts = JoysoundMusicPost
                     .where(delivery_deadline_on: ...1.month.from_now)
                     .order(delivery_deadline_on: :asc)

    # 優先度順に結合（差分を優先）
    (unmatched_posts.to_a + upcoming_posts.to_a).uniq
  end

  def self.refresh_joysound_music_post_song
    browser_manager = BrowserManager.new
    total_count = Song.music_post.count

    browser_manager.with_browser do |_browser|
      Song.music_post.each.with_index(1) do |song, i|
        logger.debug("#{i}/#{total_count}: #{((i / total_count.to_f) * 100).floor}% #{song.title}")
        browser_manager.visit(song.url)
        sleep(1.0) # 描画待ち

        error_selector = "#jp-cmp-main > div > h1.jp-cmp-h1-error"
        error = browser_manager.find(error_selector)&.inner_text
        if error == "このページは存在しません。"
          record = Song.find_by(karaoke_type: "JOYSOUND(うたスキ)", url: browser_manager.current_url)
          record&.destroy!
        end
      end
    end
  end

  def self.fetch_dam_songs
    scraper = Scrapers::DamScraper.new
    dam_songs = DamSong.order(created_at: :desc)

    # ParallelProcessorを使用してバッチ処理
    process_with_progress(dam_songs, label: "DAM Songs") do |record|
      song = Song.includes(:song_with_dam_ouchikaraoke).find_by(karaoke_type: "DAM", url: record.url)
      next if song.present?

      scraper.scrape_song_page(record)
    end
  end

  def self.update_dam_delivery_models
    scraper = Scrapers::DamScraper.new
    dam_songs = Song.dam.includes(:karaoke_delivery_models)

    # ParallelProcessorを使用してバッチ処理
    process_with_progress(dam_songs, label: "Update DAM Delivery Models") do |song|
      scraper.update_delivery_models(song)
    end
  end

  def self.update_joysound_music_post_delivery_deadline_dates
    # JOYSOUND(うたスキ)の楽曲で、song_with_joysound_utasukiが存在するものを取得
    music_post_songs = Song.music_post.includes(:song_with_joysound_utasuki)
                           .where.not(song_with_joysound_utasukis: { id: nil })

    total_count = music_post_songs.count
    updated_count = 0

    music_post_songs.each.with_index(1) do |song, i|
      logger.debug("#{i}/#{total_count}: #{((i / total_count.to_f) * 100).floor}% #{song.title}")

      # song_with_joysound_utasukiのurlからJoysoundMusicPostを検索
      jmp = JoysoundMusicPost.find_by(url: song.song_with_joysound_utasuki.url)

      if jmp && song.song_with_joysound_utasuki.delivery_deadline_date != jmp.delivery_deadline_on
        song.song_with_joysound_utasuki.update!(delivery_deadline_date: jmp.delivery_deadline_on)
        updated_count += 1
        logger.debug("Updated delivery_deadline_date for: #{song.title}")
      end
    end

    logger.info("Updated #{updated_count} songs out of #{total_count} total music post songs")
  end
end
