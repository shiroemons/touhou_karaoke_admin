class Song < ApplicationRecord
  include AlgoliaSearch

  has_one :song_with_dam_ouchikaraoke, dependent: :destroy
  has_one :song_with_joysound_utasuki, dependent: :destroy

  has_many :songs_karaoke_delivery_models, dependent: :destroy
  has_many :karaoke_delivery_models, through: :songs_karaoke_delivery_models
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

  PERMITTED_COMPOSERS = %w(ZUN ZUN(上海アリス幻樂団) ZUN[上海アリス幻樂団] ZUN，あきやまうに あきやまうに U2).freeze
  ALLOWLIST = [
    "https://www.joysound.com/web/search/song/115474", # ひれ伏せ愚民どもっ! 作曲:ARM
    "https://www.joysound.com/web/search/song/225460", # Once in a blue moon feat. らっぷびと 作曲:Coro
    "https://www.joysound.com/web/search/song/225456", # Crazy speed Hight 作曲:龍5150
    "https://www.joysound.com/web/search/song/225449"  # 愛き夜道 feat. ランコ(豚乙女)、雨天決行／魂音泉 作曲:U2，Coro
  ].freeze
  ORIGINAL_TYPE = {
    windows: "01. Windows作品",
    pc98: "02. PC-98作品",
    zuns_music_collection: "03. ZUN's Music Collection",
    akyus_untouched_score: "04. 幺樂団の歴史　～ Akyu's Untouched Score",
    commercial_books: "05. 商業書籍",
    other: "06. その他"
  }.freeze

  def self.ransackable_attributes(_auth_object = nil)
    ["title"]
  end

  algoliasearch index_name: ENV.fetch('ALGOLIA_INDEX_NAME', nil), unless: :deleted? do
    attribute :title
    attribute :reading_title do
      title_reading || ''
    end
    attribute :display_artist do
      {
        name: display_artist.name,
        reading_name: display_artist.name_reading,
        reading_name_hiragana: display_artist.name_reading.tr('ァ-ン', 'ぁ-ん'),
        karaoke_type: display_artist.karaoke_type,
        url: display_artist.url
      }
    end
    attribute :original_songs do
      original_songs_json(original_songs)
    end
    attribute :karaoke_type
    attribute :karaoke_delivery_models do
      karaoke_delivery_models_json
    end
    attribute :circle do
      {
        name: display_artist.circles.first&.name || ''
      }
    end
    attribute :url
    attribute :song_number do
      song_number.presence
    end
    attribute :delivery_deadline_date do
      song_with_joysound_utasuki&.delivery_deadline_date&.strftime("%Y/%m/%d")
    end
    attribute :musicpost_url do
      song_with_joysound_utasuki&.url
    end
    attribute :ouchikaraoke_url do
      song_with_dam_ouchikaraoke&.url
    end
    attribute :videos
  end

  def touhou?
    return false if original_songs.blank?

    original_songs.all? { _1.title != 'オリジナル' } && !original_songs.all? { _1.title == 'その他' }
  end

  def first_category(original)
    ORIGINAL_TYPE[original.original_type.to_sym]
  end

  def second_category(original)
    "#{first_category(original)} > #{format('%#04.1f', original.series_order)}. #{original.short_title}"
  end

  def third_category(original_song)
    original = original_song.original
    "#{second_category(original)} > #{format('%02d', original_song.track_number)}. #{original_song.title}"
  end

  def original_songs_json(original_songs)
    original_songs.map do |os|
      {
        title: os.title,
        original: {
          title: os.original.title,
          short_title: os.original.short_title
        },
        'categories.lvl0': first_category(os.original),
        'categories.lvl1': second_category(os.original),
        'categories.lvl2': third_category(os)
      }
    end
  end

  def karaoke_delivery_models_json
    karaoke_delivery_models.map do |kdm|
      {
        name: kdm.name,
        karaoke_type: kdm.karaoke_type
      }
    end
  end

  def videos
    v = []
    if youtube_url.present?
      m = /(?<=\?v=)(?<id>[\w\-_]+)(?!=&)/.match(youtube_url)
      v.push({ type: "YouTube", url: youtube_url, id: m[:id] })
    end
    if nicovideo_url.present?
      m = %r{(?<=watch/)(?<id>[s|n]m\d+)(?!=&)}.match(nicovideo_url)
      v.push({ type: "ニコニコ動画", url: nicovideo_url, id: m[:id] })
    end
    v
  end

  def deleted?
    return true if original_songs.blank?

    original_song_titles = original_songs.map(&:title)
    original_song_titles.include?("オリジナル") || original_song_titles.include?("その他")
  end

  def self.not_set_original_song
    includes(:display_artist, :original_songs).select do |song|
      song if song.original_songs.blank?
    end
  end

  def self.fetch_joysound_song(url = nil)
    @delivery_models = KaraokeDeliveryModel.pluck(:name, :id).to_h
    joysound_song_page_parser(url) if url.present?
  end

  def self.fetch_joysound_songs
    @delivery_models = KaraokeDeliveryModel.pluck(:name, :id).to_h
    total_count = JoysoundSong.count
    JoysoundSong.find_each.with_index(1) do |js, i|
      logger.debug("#{i}/#{total_count}: #{((i / total_count.to_f) * 100).floor}%")
      title = js.display_title.split("／").first
      unless Song.exists?(title:, url: js.url, karaoke_type: "JOYSOUND")
        logger.debug(title)
        joysound_song_page_parser(js.url)
      end
    end

    ALLOWLIST.each do |url|
      next if Song.exists?(url:, karaoke_type: "JOYSOUND")

      joysound_song_page_parser(url)
    end
  end

  def self.fetch_joysound_music_post_song
    @delivery_models = KaraokeDeliveryModel.pluck(:name, :id).to_h
    total_count = JoysoundMusicPost.count
    JoysoundMusicPost.order(:delivery_deadline_on).each.with_index(1) do |jmp, i|
      logger.debug("#{i}/#{total_count}: #{((i / total_count.to_f) * 100).floor}% #{jmp.title}")
      joysound_music_post_song_page_parser(jmp)
    end
  end

  def self.refresh_joysound_music_post_song
    browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
    total_count = Song.music_post.count
    Song.music_post.each.with_index(1) do |song, i|
      logger.debug("#{i}/#{total_count}: #{((i / total_count.to_f) * 100).floor}% #{song.title}")
      browser.goto(song.url)
      # 描画に少し時間がかかるため 1秒待つ
      sleep(1.0)

      error_selector = "#jp-cmp-main > div > h1.jp-cmp-h1-error"
      error = browser.at_css(error_selector)&.inner_text
      if error == "このページは存在しません。"
        record = Song.find_by(karaoke_type: "JOYSOUND(うたスキ)", url: browser.current_url)
        record&.destroy!
      end
    end
    browser.quit
  end

  def self.fetch_dam_songs
    @delivery_models = KaraokeDeliveryModel.pluck(:name, :id).to_h
    total_count = DamSong.count
    DamSong.find_each(order: :desc).with_index(1) do |ds, i|
      logger.debug("#{i}/#{total_count}: #{((i / total_count.to_f) * 100).floor}%")
      logger.debug(ds.title)
      song = Song.includes(:song_with_dam_ouchikaraoke).find_by(karaoke_type: "DAM", url: ds.url)
      next if song.present?

      dam_song_page_parser(ds)
    end
  end

  def self.joysound_song_page_parser(url)
    @browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
    retry_count = 0
    begin
      @browser.network.clear(:traffic)
      @browser.goto(url)
      @browser.network.wait_for_idle(duration: 1.0)

      composer_selector = "#jp-cmp-main > section:nth-child(2) > div.jp-cmp-song-block-001 > div.jp-cmp-song-visual > div.jp-cmp-song-table-001.jp-cmp-table-001 > table > tbody > tr:nth-child(3) > td > div > p"
      composer = @browser.at_css(composer_selector).inner_text

      if composer.in?(PERMITTED_COMPOSERS) || ALLOWLIST.include?(url)
        artist_selector = "#jp-cmp-main > section:nth-child(2) > div.jp-cmp-song-block-001 > div.jp-cmp-song-visual > div.jp-cmp-song-table-001.jp-cmp-table-001 > table > tbody > tr:nth-child(1) > td > div > p > a"
        atirst_el = @browser.at_css(artist_selector)
        artist_name = atirst_el.inner_text
        artist_url = atirst_el.property("href")
        display_artist = DisplayArtist.find_or_create_by!(name: artist_name, karaoke_type: "JOYSOUND", url: artist_url)

        songs_selector = "#karaokeDeliver > div > ul > li"
        @browser.css(songs_selector).each do |el|
          title = el.at_css("div > div.jp-cmp-karaoke-details > h4").inner_text
          song_number = el.at_css("div > div.jp-cmp-karaoke-details > div > dl > dd:nth-child(2)").inner_text

          delivery_models = []
          el.css("div > div.jp-cmp-karaoke-platform > ul > li").each do |kp|
            delivery_models.push(kp.at_css("img").attribute("alt"))
          end
          kdm = delivery_models.map { |dm| @delivery_models[dm] }

          song = Song.find_or_create_by!(title:, display_artist:, song_number:, karaoke_type: "JOYSOUND", url: @browser.current_url)
          song.karaoke_delivery_model_ids = kdm
        end
      end
      @browser.quit
    rescue Ferrum::TimeoutError, Ferrum::PendingConnectionsError => e
      logger.error("self.joysound_song_page_parser: #{e}")
      @browser.quit
      @browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
      retry_count += 1
      retry unless retry_count > 3
    end
  end

  def self.joysound_music_post_song_page_parser(jmp)
    @browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
    retry_count = 0
    begin
      if jmp.joysound_url.blank?
        logger.debug("joysound_url is blank: #{jmp.title}")
        return
      end

      @browser.network.clear(:traffic)
      @browser.goto(jmp.joysound_url)
      # 描画に少し時間がかかるため 1秒待つ
      sleep(1.0)

      error_selector = "#jp-cmp-main > div > h1.jp-cmp-h1-error"
      error = @browser.at_css(error_selector)&.inner_text
      if error == "このページは存在しません。"
        record = Song.find_by(karaoke_type: "JOYSOUND(うたスキ)", url: @browser.current_url)
        if record
          record.destroy!
          jmp.destroy!
          nil
        end
      else
        artist_selector = "#jp-cmp-main > section:nth-child(2) > div.jp-cmp-song-block-001 > div.jp-cmp-song-visual > div.jp-cmp-song-table-001.jp-cmp-table-001 > table > tbody > tr:nth-child(1) > td > div > p > a"
        atirst_el = @browser.at_css(artist_selector)
        artist_name = atirst_el.inner_text
        artist_url = atirst_el.property("href")
        display_artist = DisplayArtist.find_or_create_by!(name: artist_name, karaoke_type: "JOYSOUND(うたスキ)", url: artist_url)

        song_block_selector = "#jp-cmp-karaoke-kyokupro > div.jp-cmp-kyokupuro-block"
        @browser.css(song_block_selector).each do |el|
          title = el.at_css("div.jp-cmp-karaoke-details > h4").inner_text

          delivery_models = []
          el.css("div.jp-cmp-karaoke-platform > ul > li").each do |kp|
            delivery_models.push(kp.at_css("img").attribute("alt"))
          end
          kdm = delivery_models.map { |dm| @delivery_models[dm] }

          song = Song.find_or_create_by!(title:, display_artist:, karaoke_type: "JOYSOUND(うたスキ)", url: @browser.current_url)
          song.karaoke_delivery_model_ids = kdm
          if song.song_with_joysound_utasuki.blank?
            song.create_song_with_joysound_utasuki(delivery_deadline_date: jmp.delivery_deadline_on, url: jmp.url)
          else
            song.song_with_joysound_utasuki.delivery_deadline_date = jmp.delivery_deadline_on
            song.song_with_joysound_utasuki.save! if song.song_with_joysound_utasuki.changed?
          end
        end
      end
      @browser.quit
    rescue Ferrum::TimeoutError, Ferrum::PendingConnectionsError => e
      logger.error("self.joysound_music_post_song_page_parser: #{e}")
      @browser.quit
      @browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
      retry_count += 1
      retry unless retry_count > 3
    end
  end

  def self.dam_song_page_parser(dam_song)
    @browser = Ferrum::Browser.new(timeout: 10, process_timeout: 10, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
    retry_count = 0
    begin
      @browser.goto(dam_song.url)
      @browser.network.wait_for_idle(duration: 1.0)

      title_selector = "#anchor-pagetop > main > div > div > div.main-content > div.song-detail > h2"
      title = @browser.at_css(title_selector).inner_text

      title_reading_selector = "#anchor-pagetop > main > div > div > div.main-content > div.song-detail > div.song-yomi"
      title_reading = @browser.at_css(title_reading_selector)&.inner_text
      title_reading = title_reading&.gsub(/[\[\] ]/, "")

      song_number_selector = "#anchor-pagetop > main > div > div > div.main-content > div.song-detail > div.request-no > span"
      song_number = @browser.at_css(song_number_selector).inner_text

      if title.present? && title_reading.present? && song_number.present?
        record = Song.find_or_create_by!(karaoke_type: "DAM", song_number:, url: dam_song.url) do |song|
          song.title = title
          song.title_reading = title_reading
          song.display_artist = dam_song.display_artist
        end
        record.update!(title:, title_reading:, display_artist: dam_song.display_artist)

        delivery_models = []
        delivery_model_selector = "#anchor-pagetop > main > div > div > div.main-content > div.model-section > div > ul.model-list.latest-model > li > a"
        delivery_models << @browser.at_css(delivery_model_selector).inner_text
        delivery_models_selector = "#model-list > li > a"
        delivery_models_tag = @browser.css(delivery_models_selector)
        delivery_models_tag.map(&:inner_text).each { |model| delivery_models.push(model) }

        ouchikaraoke_selector = "#anchor-pagetop > main > div.content-wrap > div > div.main-content > div.service-store-section > div.service-section.is-show > div.is-pc > div > div:nth-child(1) > div.txt > a.btn-ouchikaraoke"
        ouchikaraoke_tag = @browser.at_css(ouchikaraoke_selector)
        ouchikaraoke_url = ouchikaraoke_tag&.attribute('href').present? ? ouchikaraoke_tag.property('href') : nil

        delivery_models.push("カラオケ@DAM") if ouchikaraoke_url.present?
        kdm = delivery_models.map { |dm| @delivery_models[dm] }
        record.karaoke_delivery_model_ids = kdm

        return if ouchikaraoke_url.blank? && record.song_with_dam_ouchikaraoke.blank?

        if record.song_with_dam_ouchikaraoke.blank?
          record.create_song_with_dam_ouchikaraoke(url: ouchikaraoke_url) if ouchikaraoke_url.blank?
        elsif ouchikaraoke_url.present?
          record.song_with_dam_ouchikaraoke.url = ouchikaraoke_url
          record.song_with_dam_ouchikaraoke.save! if record.song_with_dam_ouchikaraoke.changed?
        else
          record.song_with_dam_ouchikaraoke.destroy!
        end
      end
      @browser.quit
    rescue StandardError => e
      logger.error("self.dam_song_page_parser: #{e}")
      @browser.quit
      @browser = Ferrum::Browser.new(timeout: 10, process_timeout: 10, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
      retry_count += 1
      retry unless retry_count > 3
    end
  end
end
