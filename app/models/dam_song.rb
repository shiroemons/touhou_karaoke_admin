class DamSong < ApplicationRecord
  belongs_to :display_artist

  BASE_URL = "https://www.clubdam.com/karaokesearch/".freeze
  OPTION_PATH = "&contentsCode=&serviceCode=&serialNo=AT00001&filterTitle=&sort=3".freeze

  EXCEPTION_URLS = %w[
    https://www.clubdam.com/karaokesearch/artistleaf.html?artistCode=43477
  ].freeze
  EXCEPTION_WORD = %w[アニメ ゲーム 映画 Windows PlayStation PS Xbox ニンテンドーDS].freeze

  def self.fetch_dam_songs
    DisplayArtist.dam.order(id: :desc).each do |da|
      dam_song_list_parser(da) if da.url.present?
    end
  end

  def self.fetch_dam_song(display_artist)
    @browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
    dam_song_list_parser(display_artist) if display_artist.url.present?
    @browser.quit
  end

  def self.fetch_dam_touhou_songs
    retry_count = 0
    page = 1
    url = "https://www.clubdam.com/karaokesearch/?keyword=%E6%9D%B1%E6%96%B9%E3%83%97%E3%83%AD%E3%82%B8%E3%82%A7%E3%82%AF%E3%83%88&type=keyword&contentsCode=&serviceCode=&serialNo=AT00001&sort=1&pageNo="

    begin
      loop do
        @browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
        @browser.goto("#{url}#{page}")
        @browser.network.wait_for_idle(duration: 1.0)

        song_list_selector = "#anchor-pagetop > main > div.content-wrap > div > div.main-content > div.result-wrap > ul > li"
        @browser.css(song_list_selector).each do |el|
          artist_element_selector = "div.result-item-inner > div.artist-name"
          artist_el = el.at_css(artist_element_selector)
          artist_name = artist_el.inner_text
          artist_path = artist_el.at_css("a").attribute("href")
          artist_url = URI.join(BASE_URL, artist_path).to_s
          # logger.debug("#{artist_name} - #{artist_url}")
          DamArtistUrl.find_or_create_by!(url: artist_url)
          display_artist = DisplayArtist.find_or_initialize_by(karaoke_type: "DAM", url: artist_url) do |da|
            da.name = artist_name
          end

          song_element_selector = "div.result-item-inner > div.song-name"
          song_el = el.at_css(song_element_selector)
          song_title = song_el.inner_text
          song_path = song_el.at_css("a").attribute("href")
          song_url = URI.join(BASE_URL, song_path).to_s
          # logger.debug("#{song_title} - #{song_url}")
          dam_song = DamSong.find_or_create_by!(url: song_url) do |dam_song|
            dam_song.title = song_title
            dam_song.display_artist = display_artist
          end
          dam_song.update(title: song_title, display_artist:)
        end

        if @browser.css(song_list_selector).size != 100
          @browser.quit
          break
        end
        page += 1
        logger.debug("Next page: #{url}#{page}")
        @browser.quit
      end
    rescue StandardError => e
      logger.error(e)
      @browser.quit
      retry_count += 1
      retry unless retry_count > 3
    end
  end

  def self.dam_song_list_parser(display_artist)
    @browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
    retry_count = 0
    url = display_artist.url + OPTION_PATH
    begin
      @browser.goto(url)
      @browser.network.wait_for_idle(duration: 1.0)
      song_list_selector = "#anchor-pagetop > main > div > div > div.main-content > div.result-wrap > ul > li"
      @browser.css(song_list_selector).each do |el|
        song_element_selector = "div.result-item-inner > div.song-name"
        song_el = el.at_css(song_element_selector)
        song_title = song_el.inner_text
        song_path = song_el.at_css("a").attribute("href")
        song_url = URI.join(BASE_URL, song_path).to_s

        return if display_artist.name == "田原俊彦" && song_title != "サヨナラはどこか蒼い"

        description_selector = "div.result-item-inner > div.description"
        description = el.at_css(description_selector).inner_text
        if !(display_artist.url.in?(EXCEPTION_URLS) || EXCEPTION_WORD.any? { |w| description.include?(w) }) || description&.include?("東方")
          dam_song = DamSong.find_or_create_by!(url: song_url) do |dam_song|
            dam_song.title = song_title
            dam_song.display_artist = display_artist
          end
          dam_song.update!(title: song_title, display_artist: display_artist)
        end
      end
      @browser.quit
    rescue StandardError => e
      logger.error(e)
      @browser.quit
      @browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
      retry_count += 1
      retry unless retry_count > 3
    end
  end
end
