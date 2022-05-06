class DamSong < ApplicationRecord
  belongs_to :display_artist

  BASE_URL = "https://www.clubdam.com/karaokesearch/"
  OPTION_PATH = "&contentsCode=&serviceCode=&serialNo=AT00001&filterTitle=&sort=3"

  EXCEPTION_URLS = %w(
    https://www.clubdam.com/karaokesearch/artistleaf.html?artistCode=43477
  )
  EXCEPTION_WORD = %w(アニメ ゲーム 映画 Windows PlayStation PS Xbox ニンテンドーDS)

  def self.fetch_dam_songs
    @browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900])
    DisplayArtist.dam.each do |da|
      dam_song_list_parser(da) if da.url.present?
    end
    @browser.quit
  end

  def self.fetch_dam_song(display_artist)
    @browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900])
    dam_song_list_parser(display_artist) if display_artist.url.present?
    @browser.quit
  end


  def self.dam_song_list_parser(display_artist)
    retry_count = 0
    url = display_artist.url + OPTION_PATH
    begin
      @browser.goto(url)
      sleep(1.0)
      song_list_selector = "#anchor-pagetop > main > div > div > div.main-content > div.result-wrap > ul > li"
      @browser.css(song_list_selector).each do |el|
        song_element_selector = "div.result-item-inner > div.song-name"
        song_el = el.at_css(song_element_selector)
        song_title = song_el.inner_text
        song_path = song_el.at_css("a").attribute("href")
        song_url = URI.join(BASE_URL, song_path).to_s

        description_selector = "div.result-item-inner > div.description"
        description = el.at_css(description_selector).inner_text
        if display_artist.url.in?(EXCEPTION_URLS)
          if description&.include?("東方")
            DamSong.find_or_create_by!(title: song_title, url: song_url, display_artist:)
          end
        elsif EXCEPTION_WORD.any? { |w| description.include?(w) }
          if description&.include?("東方")
              DamSong.find_or_create_by!(title: song_title, url: song_url, display_artist:)
            end
          else
            DamSong.find_or_create_by!(title: song_title, url: song_url, display_artist:)
        end
      end
    rescue Ferrum::TimeoutError => e
      logger.error(e)
      @browser.network.clear(:traffic)
      retry_count += 1
      retry unless retry_count > 3
    end
  end
end
