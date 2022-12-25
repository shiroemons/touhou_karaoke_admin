class DamSong < ApplicationRecord
  belongs_to :display_artist

  BASE_URL = "https://www.clubdam.com/karaokesearch/".freeze
  OPTION_PATH = "&contentsCode=&serviceCode=&serialNo=AT00001&filterTitle=&sort=3".freeze

  EXCEPTION_URLS = %w[
    https://www.clubdam.com/karaokesearch/artistleaf.html?artistCode=43477
  ].freeze
  EXCEPTION_WORD = %w[アニメ ゲーム 映画 Windows PlayStation PS Xbox ニンテンドーDS].freeze

  def self.fetch_dam_songs
    @browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
    DisplayArtist.dam.each do |da|
      dam_song_list_parser(da) if da.url.present?
    end
    @browser.quit
  end

  def self.fetch_dam_song(display_artist)
    @browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
    dam_song_list_parser(display_artist) if display_artist.url.present?
    @browser.quit
  end

  def self.dam_song_list_parser(display_artist)
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

        description_selector = "div.result-item-inner > div.description"
        description = el.at_css(description_selector).inner_text
        if display_artist.url.in?(EXCEPTION_URLS) || EXCEPTION_WORD.any? { |w| description.include?(w) }
          DamSong.find_or_create_by!(title: song_title, url: song_url, display_artist:) if description&.include?("東方")
        else
          DamSong.find_or_create_by!(title: song_title, url: song_url, display_artist:)
        end
      end
    rescue Ferrum::TimeoutError => e
      logger.error(e)
      @browser.quit
      @browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
      retry_count += 1
      retry unless retry_count > 3
    end
  end
end
