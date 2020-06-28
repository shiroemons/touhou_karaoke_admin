class Song < ApplicationRecord
  has_one :song_with_dam_ouchikaraoke, dependent: :destroy
  has_one :song_with_joysound_utasuki, dependent: :destroy

  has_many :songs_karaoke_delivery_models, dependent: :destroy
  has_many :karaoke_delivery_models, through: :songs_karaoke_delivery_models
  has_many :songs_original_songs, dependent: :destroy
  has_many :original_songs, through: :songs_original_songs

  belongs_to :display_artist

  scope :dam, -> { where(karaoke_type: "DAM") }
  scope :joysound, -> { where(karaoke_type: "JOYSOUND") }
  scope :music_post, -> { where(karaoke_type: "JOYSOUND(うたスキ)") }

  PERMITTED_COMPOSERS = %w(ZUN ZUN(上海アリス幻樂団) ZUN[上海アリス幻樂団] ZUN，あきやまうに あきやまうに)
  ALLOWLIST = [
      "https://www.joysound.com/web/search/song/115474", # ひれ伏せ愚民どもっ! 作曲:ARM
      "https://www.joysound.com/web/search/song/225460", # Once in a blue moon feat. らっぷびと 作曲:Coro
  ]

  def self.fetch_joysound_song(url = nil)
    @delivery_models = KaraokeDeliveryModel.pluck(:name, :id).to_h
    @browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900])
    joysound_song_page_parser(url) if url.present?
    @browser.quit
  end

  def self.fetch_joysound_songs
    @delivery_models = KaraokeDeliveryModel.pluck(:name, :id).to_h
    @browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900])
    total_count = JoysoundSong.count
    JoysoundSong.all.each.with_index(1) do |js, i|
      logger.debug("#{i}/#{total_count}: #{((i/total_count.to_f)*100).floor}%")
      title = js.display_title.split("／").first
      unless Song.exists?(title: title, url: js.url, karaoke_type: "JOYSOUND")
        logger.debug(title)
        joysound_song_page_parser(js.url)
      end
    end
    @browser.quit
  end

  def self.fetch_joysound_music_post_song
    @delivery_models = KaraokeDeliveryModel.pluck(:name, :id).to_h
    @browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900])
    total_count = JoysoundMusicPost.count
    JoysoundMusicPost.order(:delivery_deadline_on).each.with_index(1) do |jmp, i|
      logger.debug("#{i}/#{total_count}: #{((i/total_count.to_f)*100).floor}%")
      logger.debug(jmp.title)
      joysound_music_post_song_page_parser(jmp)
    end
    @browser.quit
  end

  def self.fetch_dam_songs
    @delivery_models = KaraokeDeliveryModel.pluck(:name, :id).to_h
    @browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900])
    total_count = DamSong.count
    DamSong.all.each.with_index(1) do |ds, i|
      logger.debug("#{i}/#{total_count}: #{((i/total_count.to_f)*100).floor}%")
      logger.debug(ds.title)
      next if Song.exists?(karaoke_type: "DAM", url: ds.url)
      dam_song_page_parser(ds)
    end
    @browser.quit
  end

  private

  def self.joysound_song_page_parser(url)
    base_url = "https://www.joysound.com/web/"
    retry_count = 0
    begin
      @browser.goto(url)
      sleep(1.0)

      composer_selector = "#jp-cmp-main > section:nth-child(2) > div.jp-cmp-song-block-001 > div.jp-cmp-song-visual > div.jp-cmp-song-table-001.jp-cmp-table-001 > table > tbody > tr:nth-child(3) > td > div > p"
      composer = @browser.at_css(composer_selector).inner_text

      if composer.in?(PERMITTED_COMPOSERS) || ALLOWLIST.include?(url)
        artist_selector = "#jp-cmp-main > section:nth-child(2) > div.jp-cmp-song-block-001 > div.jp-cmp-song-visual > div.jp-cmp-song-table-001.jp-cmp-table-001 > table > tbody > tr:nth-child(1) > td > div > p > a"
        atirst_el = @browser.at_css(artist_selector)
        artist_name = atirst_el.inner_text
        artist_url_path = atirst_el.attribute("href")
        artist_url = URI.join(base_url, artist_url_path).to_s
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

          song = Song.find_or_create_by!(title: title, display_artist: display_artist, song_number: song_number, karaoke_type: "JOYSOUND", url: @browser.current_url)
          song.karaoke_delivery_model_ids = kdm
        end
      end
    rescue Ferrum::TimeoutError => ex
      logger.error(ex)
      retry_count += 1
      retry unless retry_count > 3
    end
  end

  def self.joysound_music_post_song_page_parser(jmp)
    base_url = "https://www.joysound.com/web/"
    retry_count = 0
    begin
      @browser.goto(jmp.joysound_url)
      sleep(1.0)
      error_selector = "#jp-cmp-main > div > h1.jp-cmp-h1-error"
      error = @browser.at_css(error_selector)&.inner_text
      if error == "このページは存在しません。"
        record = Song.find_by(karaoke_type: "JOYSOUND(うたスキ)", url: @browser.current_url)
        if record
          record.destroy!
          jmp.destroy!
          return
        end
      else
        artist_selector = "#jp-cmp-main > section:nth-child(2) > div.jp-cmp-song-block-001 > div.jp-cmp-song-visual > div.jp-cmp-song-table-001.jp-cmp-table-001 > table > tbody > tr:nth-child(1) > td > div > p > a"
        atirst_el = @browser.at_css(artist_selector)
        artist_name = atirst_el.inner_text
        artist_url_path = atirst_el.attribute("href")
        artist_url = URI.join(base_url, artist_url_path).to_s
        display_artist = DisplayArtist.find_or_create_by!(name: artist_name, karaoke_type: "JOYSOUND(うたスキ)", url: artist_url)

        song_block_selector = "#jp-cmp-karaoke-kyokupro > div.jp-cmp-kyokupuro-block"
        @browser.css(song_block_selector).each do |el|
          title = el.at_css("div.jp-cmp-karaoke-details > h4").inner_text

          delivery_models = []
          el.css("div.jp-cmp-karaoke-platform > ul > li").each do |kp|
            delivery_models.push(kp.at_css("img").attribute("alt"))
          end
          kdm = delivery_models.map { |dm| @delivery_models[dm] }

          song = Song.find_or_create_by!(title: title, display_artist: display_artist, karaoke_type: "JOYSOUND(うたスキ)", url: @browser.current_url)
          song.karaoke_delivery_model_ids = kdm
          if song.song_with_joysound_utasuki.blank?
            song.create_song_with_joysound_utasuki(delivery_deadline_date: jmp.delivery_deadline_on, url: jmp.url)
          else
            song.song_with_joysound_utasuki.delivery_deadline_date = jmp.delivery_deadline_on
            song.song_with_joysound_utasuki.save! if song.song_with_joysound_utasuki.changed?
          end
        end
      end
    rescue Ferrum::TimeoutError => ex
      logger.error(ex)
      retry_count += 1
      retry unless retry_count > 3
    end
  end

  def self.dam_song_page_parser(dam_song)
    retry_count = 0
    begin
      @browser.goto(dam_song.url)
      sleep(1.0)

      title_selector = "#anchor-pagetop > main > div > div > div.main-content > div.song-detail > h2"
      title = @browser.at_css(title_selector).inner_text

      title_reading_selector = "#anchor-pagetop > main > div > div > div.main-content > div.song-detail > div.song-yomi"
      title_reading = @browser.at_css(title_reading_selector)&.inner_text
      title_reading = title_reading&.gsub(/[\[\] ]/, "")

      song_number_selector = "#anchor-pagetop > main > div > div > div.main-content > div.song-detail > div.request-no > span"
      song_number = @browser.at_css(song_number_selector).inner_text

      record = Song.find_or_create_by!(title: title, title_reading: title_reading, karaoke_type: "DAM", display_artist: dam_song.display_artist, song_number: song_number, url: dam_song.url)

      delivery_models = []
      delivery_model_selector = "#anchor-pagetop > main > div > div > div.main-content > div.model-section > div > ul.model-list.latest-model > li > a"
      delivery_models << @browser.at_css(delivery_model_selector).inner_text
      delivery_models_selector = "#model-list > li > a"
      delivery_models_tag = @browser.css(delivery_models_selector)
      delivery_models_tag.map(&:inner_text).each { |model| delivery_models.push(model) }

      ouchikaraoke_selector = "#anchor-pagetop > main > div > div > div.main-content > div.service-section.is-show > div.is-pc > div > a.btn-link.btn-ouchikaraoke"
      ouchikaraoke_tag = @browser.at_css(ouchikaraoke_selector)
      ouchikaraoke_url = ouchikaraoke_tag&.attribute('href')&.gsub(/^.*redirectUrl=/, "")

      if ouchikaraoke_url != "" && !ouchikaraoke_url.nil?
        delivery_models.push("カラオケ@DAM")
      end
      kdm = delivery_models.map { |dm| @delivery_models[dm] }
      record.karaoke_delivery_model_ids = kdm

      if ouchikaraoke_url.present?
        if record.song_with_dam_ouchikaraoke.blank?
          record.create_song_with_dam_ouchikaraoke(url: ouchikaraoke_url)
        else
          record.song_with_dam_ouchikaraoke.url = ouchikaraoke_url
          record.song_with_dam_ouchikaraoke.save! if record.song_with_dam_ouchikaraoke.changed?
        end
      end
    rescue => e
      logger.error(e)
      retry_count += 1
      retry unless retry_count > 3
    end
  end
end
