class DamSong < ApplicationRecord
  belongs_to :display_artist

  def self.ransackable_attributes(_auth_object = nil)
    ["title"]
  end

  def self.fetch_dam_song(song_url)
    raise "Not DAM URL" unless song_url.start_with?(Constants::Karaoke::Dam::SONG_URL)

    @browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
    @browser.goto(song_url)
    @browser.network.wait_for_idle(duration: 1.0)

    title_selector = "#anchor-pagetop > main > div > div > div.main-content > div.song-detail > h2"
    song_title = @browser.at_css(title_selector).inner_text

    artist_selector = "#anchor-pagetop > main > div.content-wrap > div > div.main-content > div.song-detail > div.artist-detail"
    artist_el = @browser.at_css(artist_selector)
    artist_name = artist_el.inner_text
    artist_path = artist_el.at_css("a").attribute("href")
    artist_url = URI.join(Constants::Karaoke::Dam::BASE_URL, artist_path).to_s

    display_artist = DisplayArtist.find_or_initialize_by(karaoke_type: "DAM", url: artist_url) do |da|
      da.name = artist_name
    end
    dam_song = DamSong.find_or_create_by!(url: song_url) do |song|
      song.title = song_title
      song.display_artist = display_artist
    end
    dam_song.update(title: song_title, display_artist:)
    @browser.quit
  end

  def self.fetch_dam_touhou_songs
    retry_count = 0
    page = 1
    url = Constants::Karaoke::Dam::SEARCH_URL

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
          artist_url = URI.join(Constants::Karaoke::Dam::BASE_URL, artist_path).to_s
          # logger.debug("#{artist_name} - #{artist_url}")
          DamArtistUrl.find_or_create_by!(url: artist_url)
          display_artist = DisplayArtist.find_or_initialize_by(karaoke_type: "DAM", url: artist_url) do |da|
            da.name = artist_name
          end

          song_element_selector = "div.result-item-inner > div.song-name"
          song_el = el.at_css(song_element_selector)
          song_title = song_el.inner_text
          song_path = song_el.at_css("a").attribute("href")
          song_url = URI.join(Constants::Karaoke::Dam::BASE_URL, song_path).to_s
          # logger.debug("#{song_title} - #{song_url}")
          dam_song = DamSong.find_or_create_by!(url: song_url) do |song|
            song.title = song_title
            song.display_artist = display_artist
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
      @browser&.quit
      retry_count += 1
      retry unless retry_count > 3
    end
  end

  def self.dam_song_list_parser(display_artist)
    @browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
    retry_count = 0
    url = display_artist.url + Constants::Karaoke::Dam::OPTION_PATH
    begin
      @browser.goto(url)
      @browser.network.wait_for_idle(duration: 1.0)
      song_list_selector = "#anchor-pagetop > main > div > div > div.main-content > div.result-wrap > ul > li"
      @browser.css(song_list_selector).each do |el|
        song_element_selector = "div.result-item-inner > div.song-name"
        song_el = el.at_css(song_element_selector)
        song_title = song_el.inner_text
        song_path = song_el.at_css("a").attribute("href")
        song_url = URI.join(Constants::Karaoke::Dam::BASE_URL, song_path).to_s

        next if display_artist.name == "田原俊彦" && song_title != "サヨナラはどこか蒼い"

        description_selector = "div.result-item-inner > div.description"
        description = el.at_css(description_selector).inner_text
        next unless !(display_artist.url.in?(Constants::Karaoke::Dam::EXCEPTION_URLS) || Constants::Karaoke::Dam::EXCEPTION_WORDS.any? { |w| description.include?(w) }) || description&.include?("東方")

        dam_song = DamSong.find_or_create_by!(url: song_url) do |song|
          song.title = song_title
          song.display_artist = display_artist
        end
        dam_song.update!(title: song_title, display_artist:)
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
