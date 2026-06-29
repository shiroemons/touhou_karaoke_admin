# frozen_string_literal: true

module Scrapers
  class DamSongScraper
    SEARCH_SONG_LIST_SELECTOR = "#anchor-pagetop > main > div.content-wrap > div > div.main-content > div.result-wrap > ul > li"
    ARTIST_SONG_LIST_SELECTOR = "#anchor-pagetop > main > div > div > div.main-content > div.result-wrap > ul > li"
    TITLE_SELECTOR = "#anchor-pagetop > main > div > div > div.main-content > div.song-detail > h2"
    ARTIST_SELECTOR = "#anchor-pagetop > main > div.content-wrap > div > div.main-content > div.song-detail > div.artist-detail"

    def fetch_song(song_url)
      raise "Not DAM URL" unless song_url.start_with?(Constants::Karaoke::Dam::SONG_URL)

      browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
      browser.goto(song_url)
      browser.network.wait_for_idle(duration: 1.0)
      upsert_direct_song(song_url, browser)
    ensure
      browser&.quit
    end

    def fetch_touhou_songs(progress: nil)
      retry_count = 0
      page = 1
      processed_count = 0
      total_pages = nil
      Admin::ProgressReporter.report(progress:, percentage: 2, status: "取得準備中", label: "DAM検索ページへ接続しています...", detail: nil)

      begin
        loop do
          browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
          browser.goto("#{Constants::Karaoke::Dam::SEARCH_URL}#{page}")
          browser.network.wait_for_idle(duration: 1.0)
          song_elements = browser.css(SEARCH_SONG_LIST_SELECTOR)
          total_pages ||= self.class.detect_total_pages(browser, song_elements.size)
          report_page_progress(progress, page:, total_pages:, item_index: 0, item_count: song_elements.size, processed_count:, current: page, total: total_pages, label_suffix: "処理しています")
          processed_count = save_search_song_elements(song_elements, progress, page, total_pages, processed_count)

          break if song_elements.size != 100

          page += 1
          Rails.logger.debug { "Next page: #{Constants::Karaoke::Dam::SEARCH_URL}#{page}" }
        ensure
          browser&.quit
        end
      rescue StandardError => e
        retry_count += 1
        log_fetch_retry(resource: :dam_song, url: "#{Constants::Karaoke::Dam::SEARCH_URL}#{page}", error: e, retry_count:)
        retry unless retry_count > 3
      end
    end

    def parse_artist_song_list(display_artist)
      retry_count = 0
      url = display_artist.url + Constants::Karaoke::Dam::OPTION_PATH

      loop do
        browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
        begin
          browser.goto(url)
          browser.network.wait_for_idle(duration: 1.0)
          browser.css(ARTIST_SONG_LIST_SELECTOR).each do |element|
            save_artist_song_element(display_artist, element)
          end
          break
        rescue StandardError => e
          retry_count += 1
          log_fetch_retry(resource: :dam_song, url:, error: e, retry_count:)
          break if retry_count > 3
        ensure
          browser&.quit
        end
      end
    end

    def self.detect_total_pages(browser, page_size)
      pages_from_links = browser.css('a[href*="pageNo="]').filter_map do |link|
        link.attribute('href').to_s[/pageNo=(\d+)/, 1]&.to_i
      end.max
      body_text = browser.at_css('body')&.inner_text.to_s
      counts = body_text.scan(/([0-9,]+)\s*件/).filter_map do |match|
        match.first.delete(',').to_i
      end
      result_count = counts.select { |count| count >= page_size }.max
      pages_from_count = (result_count.to_f / 100).ceil if result_count

      [pages_from_links, pages_from_count].compact.max
    rescue StandardError => e
      Rails.logger.debug { "DAM Touhou fetch total page detection failed: #{e.message}" }
      nil
    end

    def self.progress_percentage(page:, item_index:, item_count:, total_pages:)
      item_fraction = item_count.positive? ? item_index.to_f / item_count : 0.0
      ratio = if total_pages.to_i.positive?
                ((page - 1) + item_fraction) / total_pages.to_f
              else
                ((page - 1) + item_fraction) / (page + 1).to_f
              end

      (8 + (88 * ratio)).floor.clamp(8, 96)
    end

    private

    def log_fetch_retry(resource:, url:, error:, retry_count:)
      level = retry_count > 3 ? :error : :warn
      action = retry_count > 3 ? :error : :retry
      Admin::OperationLogger.log(level:, event: :external_fetch, action:, resource:, url:, retry_count:, max_retries: 3, error: error.message)
    end

    def upsert_direct_song(song_url, browser)
      song_title = browser.at_css(TITLE_SELECTOR).inner_text
      artist_el = browser.at_css(ARTIST_SELECTOR)
      artist_name = artist_el.inner_text
      artist_url = URI.join(Constants::Karaoke::Dam::BASE_URL, artist_el.at_css("a").attribute("href")).to_s
      display_artist = DisplayArtist.find_or_initialize_by(karaoke_type: "DAM", url: artist_url) { |artist| artist.name = artist_name }
      dam_song = DamSong.find_or_create_by!(url: song_url) do |song|
        song.title = song_title
        song.display_artist = display_artist
      end
      dam_song.update(title: song_title, display_artist:)
    end

    def save_search_song_elements(song_elements, progress, page, total_pages, processed_count)
      song_elements.each_with_index do |element, index|
        save_search_song_element(element)
        processed_count += 1

        next unless ((index + 1) % 10).zero? || index + 1 == song_elements.size

        report_page_progress(
          progress,
          page:,
          total_pages:,
          item_index: index + 1,
          item_count: song_elements.size,
          processed_count:,
          current: total_pages ? ((page - 1) * 100) + index + 1 : processed_count,
          total: total_pages ? total_pages * 100 : nil,
          label_suffix: "保存しています"
        )
      end
      processed_count
    end

    def save_search_song_element(element)
      artist_el = element.at_css("div.result-item-inner > div.artist-name")
      artist_name = artist_el.inner_text
      artist_url = URI.join(Constants::Karaoke::Dam::BASE_URL, artist_el.at_css("a").attribute("href")).to_s
      DamArtistUrl.find_or_create_by!(url: artist_url)
      display_artist = DisplayArtist.find_or_initialize_by(karaoke_type: "DAM", url: artist_url) { |artist| artist.name = artist_name }
      song_el = element.at_css("div.result-item-inner > div.song-name")
      song_title = song_el.inner_text
      song_url = URI.join(Constants::Karaoke::Dam::BASE_URL, song_el.at_css("a").attribute("href")).to_s
      dam_song = DamSong.find_or_create_by!(url: song_url) do |song|
        song.title = song_title
        song.display_artist = display_artist
      end
      dam_song.update(title: song_title, display_artist:)
    end

    def save_artist_song_element(display_artist, element)
      song_el = element.at_css("div.result-item-inner > div.song-name")
      song_title = song_el.inner_text
      song_url = URI.join(Constants::Karaoke::Dam::BASE_URL, song_el.at_css("a").attribute("href")).to_s
      return if display_artist.name == "田原俊彦" && song_title != "サヨナラはどこか蒼い"

      description = element.at_css("div.result-item-inner > div.description").inner_text
      return unless dam_artist_song_allowed?(display_artist, description)

      dam_song = DamSong.find_or_create_by!(url: song_url) do |song|
        song.title = song_title
        song.display_artist = display_artist
      end
      dam_song.update!(title: song_title, display_artist:)
    end

    def dam_artist_song_allowed?(display_artist, description)
      !(display_artist.url.in?(Constants::Karaoke::Dam::EXCEPTION_URLS) || Constants::Karaoke::Dam::EXCEPTION_WORDS.any? { |word| description.include?(word) }) || description&.include?("東方")
    end

    def report_page_progress(progress, context)
      Admin::ProgressReporter.report(
        progress:,
        percentage: self.class.progress_percentage(page: context.fetch(:page), item_index: context.fetch(:item_index), item_count: context.fetch(:item_count), total_pages: context.fetch(:total_pages)),
        status: "外部サイト取得中",
        label: "DAM検索結果 #{context.fetch(:page)}/#{context.fetch(:total_pages) || '?'} ページ目を#{context.fetch(:label_suffix)}",
        detail: "処理済み: #{context.fetch(:processed_count)}件",
        current: context.fetch(:current),
        total: context.fetch(:total)
      )
    end
  end
end
