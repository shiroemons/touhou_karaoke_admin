# frozen_string_literal: true

module Scrapers
  class JoysoundSongScraper
    SONG_SELECTOR = '[data-testid="card-information"]'
    SONG_LINK_SELECTOR = 'a[href^="/web/search/song/"]'
    DIRECT_TITLE_SELECTOR = '[data-testid="card-information"] p'

    def fetch_touhou_songs(progress: nil)
      browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
      Admin::ProgressReporter.report(progress:, percentage: 2, status: "取得準備中", label: "JOYSOUND東方系検索ページへ接続しています...", detail: nil)
      browser.goto(Constants::Karaoke::Joysound::TOUHOU_GENRE_URL)
      browser.network.wait_for_idle(duration: 1.0)

      page_counter = 1
      processed_count = 0
      total_pages = nil
      loop do
        Rails.logger.info("[INFO] page #{page_counter}.")
        song_elements = browser.css(SONG_SELECTOR)
        total_pages ||= self.class.detect_total_pages(browser, song_elements.size)
        context = {
          page_counter:,
          total_pages:,
          item_index: 0,
          item_count: song_elements.size,
          processed_count:,
          current: page_counter,
          total: total_pages,
          label_suffix: "処理しています"
        }
        report_page_progress(progress, context)
        processed_count = save_song_elements(song_elements, progress:, page_counter:, total_pages:, processed_count:)

        next_button = browser.css("nav button").find { |button| button.inner_text.strip == (page_counter + 1).to_s }
        break if next_button.blank?

        next_button.focus.click
        browser.network.wait_for_idle(duration: 1.0)
        sleep(1.0)
        page_counter += 1
      end
    ensure
      browser&.quit
    end

    def fetch_song_direct(url:)
      browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
      browser.goto(url)
      browser.network.wait_for_idle(duration: 1.0)

      display_title = browser.at_css(DIRECT_TITLE_SELECTOR)&.text
      return if display_title.blank?

      record = JoysoundSong.find_or_initialize_by(display_title:, url:)
      record.smartphone_service_enabled = false
      record.home_karaoke_enabled = false
      record.save! if record.changed?
    ensure
      browser&.quit
    end

    def self.display_title(link)
      title = link.at_css("p")&.inner_text&.strip
      artist = link.at_css("div.font-medium")&.inner_text&.strip

      [title, artist].compact_blank.join("／")
    end

    def self.detect_total_pages(browser, page_size)
      return nil unless page_size.positive?

      body_text = browser.at_css("body")&.inner_text.to_s
      result_count = body_text[/曲一覧\(([0-9,]+)件\)/, 1]&.delete(",")&.to_i ||
                     body_text[/検索結果\s*\(([0-9,]+)件\)/, 1]&.delete(",")&.to_i ||
                     body_text[/曲\(([0-9,]+)件\)/, 1]&.delete(",")&.to_i
      return nil unless result_count

      (result_count.to_f / page_size).ceil
    rescue StandardError => e
      Rails.logger.debug { "JOYSOUND Touhou fetch total page detection failed: #{e.message}" }
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

    def save_song_elements(song_elements, progress:, page_counter:, total_pages:, processed_count:)
      song_elements.each_with_index do |element, index|
        save_song_element(element)
        processed_count += 1

        next unless ((index + 1) % 10).zero? || index + 1 == song_elements.size

        context = {
          page_counter:,
          total_pages:,
          item_index: index + 1,
          item_count: song_elements.size,
          processed_count:,
          current: total_pages ? ((page_counter - 1) * 20) + index + 1 : processed_count,
          total: total_pages ? total_pages * 20 : nil,
          label_suffix: "保存しています"
        }
        report_page_progress(progress, context)
      end
      processed_count
    end

    def save_song_element(element)
      link = element.at_css(SONG_LINK_SELECTOR)
      return if link.blank?

      url = URI.join(Constants::Karaoke::Joysound::BASE_URL, link.attribute("href")).to_s
      display_title = self.class.display_title(link)
      return if display_title.blank?

      tags = element.css("span").map { |tag| tag.inner_text.strip }
      record = JoysoundSong.find_or_initialize_by(display_title:, url:)
      record.smartphone_service_enabled = tags.include?("スマホサービス")
      record.home_karaoke_enabled = tags.include?("家庭用カラオケ")
      record.save! if record.changed?
    end

    def report_page_progress(progress, context)
      Admin::ProgressReporter.report(
        progress:,
        percentage: self.class.progress_percentage(
          page: context.fetch(:page_counter),
          item_index: context.fetch(:item_index),
          item_count: context.fetch(:item_count),
          total_pages: context.fetch(:total_pages)
        ),
        status: "外部サイト取得中",
        label: "JOYSOUND東方系検索結果 #{context.fetch(:page_counter)}/#{context.fetch(:total_pages) || '?'} ページ目を#{context.fetch(:label_suffix)}",
        detail: "処理済み: #{context.fetch(:processed_count)}件",
        current: context.fetch(:current),
        total: context.fetch(:total)
      )
    end
  end
end
