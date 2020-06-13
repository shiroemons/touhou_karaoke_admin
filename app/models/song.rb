class Song < ApplicationRecord
  has_one :song_with_dam_ouchikaraoke, dependent: :destroy
  has_one :song_with_joysound_utasuki, dependent: :destroy

  has_many :songs_karaoke_delivery_models
  has_many :karaoke_delivery_models, through: :songs_karaoke_delivery_models
  has_many :songs_original_songs
  has_many :original_songs, through: :songs_original_songs

  belongs_to :display_artist

  PERMITTED_COMPOSERS = %w(ZUN ZUN(上海アリス幻樂団) あきやまうに)

  def self.fetch_joysound_song
    @delivery_models = KaraokeDeliveryModel.pluck(:name, :id).to_h
    @browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900])
    total_count = JoysoundSong.count
    JoysoundSong.all.each.with_index(1) do |js, i|
      puts "#{i}/#{total_count}: #{((i/total_count.to_f)*100).floor}%"
      title = js.display_title.split("／").first
      unless Song.exists?(title: title, url: js.url)
        puts title
        joysound_song_page_parser(js.url)
      end
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
      @browser.screenshot(path: "joysound.png")

      composer_selector = "#jp-cmp-main > section:nth-child(2) > div.jp-cmp-song-block-001 > div.jp-cmp-song-visual > div.jp-cmp-song-table-001.jp-cmp-table-001 > table > tbody > tr:nth-child(3) > td > div > p"
      composer = @browser.at_css(composer_selector).inner_text

      if composer.in?(PERMITTED_COMPOSERS)
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
      p ex
      retry_count += 1
      retry unless retry_count > 3
    end

  end
end
