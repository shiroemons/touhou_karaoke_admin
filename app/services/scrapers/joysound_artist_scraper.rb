# frozen_string_literal: true

module Scrapers
  class JoysoundArtistScraper
    ARTIST_READING_SELECTOR = "#jp-cmp-main > section:nth-child(2) > header > div.jp-cmp-h1-003-title > h1 > span"

    def initialize(browser_manager_factory: BrowserManager.method(:new))
      @browser_manager_factory = browser_manager_factory
    end

    def fetch_artist_readings(progress: nil)
      records = DisplayArtist.joysound.name_reading_empty
      total_count = records.count
      reporter = progress_reporter(progress, status: "JOYSOUNDアーティスト取得中", label: "JOYSOUNDアーティスト読みを取得しています")

      with_browser(timeout: 30) do |browser|
        records.each.with_index(1) do |display_artist, index|
          Rails.logger.debug { "#{index}/#{total_count}: #{((index / total_count.to_f) * 100).floor}%" }
          reporter&.advance(current: index - 1, total: total_count, force: true)
          browser.goto(display_artist.url)
          browser.network.wait_for_idle(duration: 1.0)
          update_artist_reading(display_artist, browser)
          reporter&.advance(current: index, total: total_count, force: true)
        end
      end
    end

    def register_music_post_artists(progress: nil)
      error_artist = []
      artists = unregistered_music_post_artists
      reporter = progress_reporter(progress, status: "ミュージックポストアーティスト取得中", label: "ミュージックポストアーティストを検索しています")

      with_browser(timeout: 10, window_size: [1440, 2000]) do |browser|
        artists.each.with_index(1) do |artist, index|
          reporter&.advance(current: index - 1, total: artists.count, force: true)
          register_music_post_artist(browser, artist, error_artist)
          reporter&.advance(current: index, total: artists.count, force: true)
        end
      end
    ensure
      Rails.logger.debug { "未登録アーティスト：#{error_artist}" } if error_artist.present?
    end

    def self.progress_percentage(current, total)
      Admin::ProgressReporter.percentage(current, total)
    end

    def self.search_url(artist)
      uri = URI.join(Constants::Karaoke::Joysound::BASE_URL, "search/artist")
      uri.query = URI.encode_www_form(match: 1, keyword: artist)
      uri.to_s
    end

    def self.search_no_data?(browser)
      browser.at_css("body")&.inner_text.to_s.include?("該当データがありません")
    end

    def self.search_result_links(browser)
      browser.css('a[href^="/web/search/artist/"]')
    end

    def self.search_result_name(link)
      link.css("p").map { |node| node.inner_text.to_s.strip }.find(&:present?) ||
        link.inner_text.to_s.gsub(/\A新曲あり/, "").strip
    end

    def self.name_reading(browser, artist)
      reading = browser.css("main section p").map { |node| node.inner_text.to_s.strip }.find do |text|
        text.match?(/\A[（(].+[）)]\z/)
      end
      lines = browser.at_css("body")&.inner_text.to_s.lines.map(&:strip).compact_blank
      artist_index = lines.index(artist)
      reading ||= lines[(artist_index || -1) + 1] if artist_index

      return "" unless reading&.match?(/\A[（(].+[）)]\z/)

      reading.gsub(/[（）()]/, "")
    end

    def self.absolute_joysound_url(path)
      URI.join(Constants::Karaoke::Joysound::BASE_URL, path).to_s
    end

    private

    attr_reader :browser_manager_factory

    def with_browser(options, &)
      browser_manager_factory.call(options).with_browser(&)
    end

    def progress_reporter(progress, status:, label:)
      return unless progress

      Admin::ProgressReporter.new(progress:, status:, label:)
    end

    def update_artist_reading(display_artist, browser)
      artist_el = browser.at_css(ARTIST_READING_SELECTOR)
      name_reading = artist_el&.inner_text&.gsub(/[（）]/, "")
      return if name_reading.blank?

      Rails.logger.debug(name_reading)
      display_artist.update!(name_reading:)
    end

    def unregistered_music_post_artists
      music_post_artists = JoysoundMusicPost.distinct.pluck(:artist).sort
      completed_artists = DisplayArtist.music_post.where.not(name_reading: [nil, ""]).distinct.pluck(:name).sort
      music_post_artists - completed_artists
    end

    def register_music_post_artist(browser, artist, error_artist)
      rescue_count = 0

      begin
        browser.goto(self.class.search_url(artist))
        browser.network.wait_for_idle(duration: 1.0)

        if self.class.search_no_data?(browser)
          remove_missing_music_post_artist(artist)
        else
          upsert_music_post_artist(browser, artist)
        end
      rescue Ferrum::NodeNotFoundError => e
        rescue_count += 1
        if rescue_count > 3
          Admin::OperationLogger.log(level: :error, event: :external_fetch, action: :error, resource: :display_artist, name: artist, retry_count: rescue_count, max_retries: 3, error: e.message)
          browser.screenshot(path: "tmp/music_post_#{artist.tr('/', '／')}.png")
          error_artist << artist
        else
          browser.network.clear(:traffic)
          Admin::OperationLogger.log(level: :warn, event: :external_fetch, action: :retry, resource: :display_artist, name: artist, retry_count: rescue_count, max_retries: 3, error: e.message)
          retry
        end
      end
    end

    def remove_missing_music_post_artist(artist)
      JoysoundMusicPost.where(artist:).destroy_all
      DisplayArtist.find_by(name: artist, karaoke_type: "JOYSOUND(うたスキ)")&.destroy
    end

    def upsert_music_post_artist(browser, artist)
      artist_link = self.class.search_result_links(browser).find do |link|
        self.class.search_result_name(link) == artist
      end
      return unless artist_link

      artist_url = self.class.absolute_joysound_url(artist_link.attribute("href").to_s)
      display_artist = DisplayArtist.find_or_initialize_by(name: artist, karaoke_type: "JOYSOUND(うたスキ)")
      return unless display_artist.new_record? || display_artist.url != artist_url || display_artist.name_reading.blank?

      browser.goto(artist_url)
      browser.network.wait_for_idle(duration: 1.0)
      display_artist.name_reading = self.class.name_reading(browser, artist)
      display_artist.url = browser.current_url
      display_artist.save!
    end
  end
end
