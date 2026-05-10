class JoysoundSong < ApplicationRecord
  validates :display_title, presence: true
  validates :url, presence: true

  scope :enabled_smartphone_service, -> { where(smartphone_service_enabled: true) }
  scope :enabled_home_karaoke, -> { where(home_karaoke_enabled: true) }

  def self.ransackable_attributes(_auth_object = nil)
    ["display_title"]
  end

  def self.add_delivery_model
    smartphone_service = KaraokeDeliveryModel.find_by(karaoke_type: "JOYSOUND", name: "スマホサービス")
    home_karaoke = KaraokeDeliveryModel.find_by(karaoke_type: "JOYSOUND", name: "家庭用カラオケ")
    enabled_smartphone_service.each do |js|
      title = js.display_title.split("／").first
      url = js.url
      song = Song.find_by(title:, url:, karaoke_type: "JOYSOUND")
      song.karaoke_delivery_models << smartphone_service if song.present? && !song.karaoke_delivery_models&.include?(smartphone_service)
    end
    enabled_home_karaoke.each do |js|
      title = js.display_title.split("／").first
      url = js.url
      song = Song.find_by(title:, url:, karaoke_type: "JOYSOUND")
      song.karaoke_delivery_models << home_karaoke if song.present? && !song.karaoke_delivery_models&.include?(home_karaoke)
    end
  end

  def self.fetch_joysound_touhou_songs(progress: nil)
    url = Constants::Karaoke::Joysound::TOUHOU_GENRE_URL

    browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
    begin
      progress&.call(percentage: 2, status: "取得準備中", label: "JOYSOUND東方系検索ページへ接続しています...", detail: nil)
      browser.goto(url)
      browser.network.wait_for_idle(duration: 1.0)

      song_selector = '[data-testid="card-information"]'
      song_link_selector = 'a[href^="/web/search/song/"]'

      page_counter = 1
      processed_count = 0
      total_pages = nil
      loop do
        logger.info("[INFO] page #{page_counter}.")
        song_elements = browser.css(song_selector)
        total_pages ||= detect_joysound_search_total_pages(browser, song_elements.size)
        progress&.call(
          percentage: joysound_touhou_progress_percentage(page: page_counter, item_index: 0, item_count: song_elements.size, total_pages:),
          status: "外部サイト取得中",
          label: "JOYSOUND東方系検索結果 #{page_counter}/#{total_pages || '?'} ページ目を処理しています",
          detail: "処理済み: #{processed_count}件",
          current: page_counter,
          total: total_pages
        )

        song_elements.each_with_index do |el, index|
          link = el.at_css(song_link_selector)
          next if link.blank?

          url = URI.join(Constants::Karaoke::Joysound::BASE_URL, link.attribute("href")).to_s
          display_title = joysound_display_title(link)
          next if display_title.blank?

          tags = el.css("span").map { |tag| tag.inner_text.strip }
          smartphone_service = tags.include?("スマホサービス")
          home_karaoke = tags.include?("家庭用カラオケ")

          record = find_or_initialize_by(display_title:, url:)
          record.smartphone_service_enabled = smartphone_service
          record.home_karaoke_enabled = home_karaoke
          record.save! if record.changed?
          processed_count += 1

          next unless ((index + 1) % 10).zero? || index + 1 == song_elements.size

          progress&.call(
            percentage: joysound_touhou_progress_percentage(page: page_counter, item_index: index + 1, item_count: song_elements.size, total_pages:),
            status: "外部サイト取得中",
            label: "JOYSOUND東方系検索結果 #{page_counter}/#{total_pages || '?'} ページ目を保存しています",
            detail: "処理済み: #{processed_count}件",
            current: total_pages ? ((page_counter - 1) * 20) + index + 1 : processed_count,
            total: total_pages ? total_pages * 20 : nil
          )
        end

        next_button = browser.css("nav button").find { |button| button.inner_text.strip == (page_counter + 1).to_s }
        if next_button.blank?
          puts "最後のページ"
          break
        end

        next_button.focus.click
        browser.network.wait_for_idle(duration: 1.0)
        sleep(1.0)
        page_counter += 1
      end
    ensure
      browser.quit
    end
  end

  def self.fetch_joysound_song_direct(url: nil)
    browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
    begin
      browser.goto(url)
      browser.network.wait_for_idle(duration: 1.0)

      display_title = browser.at_css('[data-testid="card-information"] p')&.text
      return if display_title.blank?

      record = find_or_initialize_by(display_title:, url:)
      smartphone_service = false
      home_karaoke = false
      record.smartphone_service_enabled = smartphone_service
      record.home_karaoke_enabled = home_karaoke
      record.save! if record.changed?
    ensure
      browser.quit
    end
  end

  def self.joysound_display_title(link)
    title = link.at_css("p")&.inner_text&.strip
    artist = link.at_css("div.font-medium")&.inner_text&.strip

    [title, artist].compact_blank.join("／")
  end

  def self.detect_joysound_search_total_pages(browser, page_size)
    return nil unless page_size.positive?

    body_text = browser.at_css("body")&.inner_text.to_s
    result_count = body_text[/曲一覧\(([0-9,]+)件\)/, 1]&.delete(",")&.to_i ||
                   body_text[/検索結果\s*\(([0-9,]+)件\)/, 1]&.delete(",")&.to_i ||
                   body_text[/曲\(([0-9,]+)件\)/, 1]&.delete(",")&.to_i
    return nil unless result_count

    (result_count.to_f / page_size).ceil
  rescue StandardError => e
    logger.debug("JOYSOUND Touhou fetch total page detection failed: #{e.message}")
    nil
  end

  def self.joysound_touhou_progress_percentage(page:, item_index:, item_count:, total_pages:)
    item_fraction = item_count.positive? ? item_index.to_f / item_count : 0.0
    ratio = if total_pages.to_i.positive?
              ((page - 1) + item_fraction) / total_pages.to_f
            else
              ((page - 1) + item_fraction) / (page + 1).to_f
            end

    (8 + (88 * ratio)).floor.clamp(8, 96)
  end
end
