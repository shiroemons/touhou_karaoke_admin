class JoysoundMusicPost < ApplicationRecord
  validates :title, presence: true
  validates :artist, presence: true
  validates :producer, presence: true
  validates :delivery_deadline_on, presence: true
  validates :url, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[artist title]
  end

  def self.fetch_music_post(progress: nil)
    url_zun = Constants::Karaoke::Joysound::MUSIC_POST_ZUN_URL
    url_u2 = Constants::Karaoke::Joysound::MUSIC_POST_AKIYAMA_URL

    music_post_parser(url_zun, progress:, progress_range: 8..52, label: "ZUN楽曲のミュージックポストを取得しています")
    music_post_parser(url_u2, progress:, progress_range: 52..96, label: "あきやまうに楽曲のミュージックポストを取得しています")
  end

  def self.fetch_music_post_song_joysound_url(progress: nil)
    browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 2000], browser_options: { 'no-sandbox': nil })
    search_option = "?sortOrder=new&orderBy=desc&startIndex=0#songlist"

    artist_names = JoysoundMusicPost.where(joysound_url: "").pluck(:artist)
    display_artists = DisplayArtist.music_post.where(name: artist_names)
    total_count = display_artists.count
    display_artists.each.with_index(1) do |da, index|
      progress&.call(
        percentage: progress_percentage(index - 1, total_count),
        status: "JOYSOUND URL取得中",
        label: "ミュージックポストのJOYSOUND URLを検索しています",
        detail: "処理済み: #{index - 1}/#{total_count}アーティスト",
        current: index - 1,
        total: total_count
      )
      url = da.url + search_option
      browser.goto(url)
      # 描画に少し時間がかかるため 1秒待つ
      sleep(1.0)

      loop do
        song_list_selector = "#songlist > div.jp-cmp-music-list-001.jp-cmp-music-list-song-002 > ul > li"
        browser.css(song_list_selector).each do |el|
          url_path = el.at_css("a").attribute("href")
          url = URI.join(Constants::Karaoke::Joysound::BASE_URL, url_path).to_s
          display_title = el.at_css("div > a > h3").inner_text
          title = display_title.split("／").first
          record = JoysoundMusicPost.find_by(artist: da.name, title:)
          if record
            record.joysound_url = url
            record.save! if record.changed?
          end
        end

        next_selector = "nav > div.jp-cmp-sp-none > div.jp-cmp-btn-pager-next.ng-scope.ng-scope"
        next_text = browser.at_css(next_selector)&.inner_text
        break unless next_text == "次の20件"

        browser.at_css(next_selector).at_css("a").focus.click
        sleep(1.0)
      end
      progress&.call(
        percentage: progress_percentage(index, total_count),
        status: "JOYSOUND URL取得中",
        label: "ミュージックポストのJOYSOUND URLを検索しています",
        detail: "処理済み: #{index}/#{total_count}アーティスト",
        current: index,
        total: total_count
      )
    end
  rescue StandardError => e
    logger.error(e)
    browser.screenshot(path: "tmp/music_post.png")
  end

  def self.music_post_parser(url, progress: nil, progress_range: 8..96, label: "ミュージックポストを取得しています")
    browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
    retry_count = 0
    page = 1
    processed_count = 0
    begin
      browser.goto(url)
      browser.network.wait_for_idle(duration: 1.0)
      loop do
        music_block_selector = "#box_music_list_bottom > div.music_block"
        blocks = browser.css(music_block_selector)
        progress&.call(
          percentage: unknown_page_progress(page, 0, blocks.size, progress_range),
          status: "ミュージックポスト取得中",
          label:,
          detail: "処理済み: #{processed_count}件 / #{page}ページ目",
          current: processed_count,
          total: nil
        )
        blocks.each_with_index do |el, index|
          music_post_url = el.at_css("a").property("href")

          title_selector = "div > span.music_name"
          title = el.at_css(title_selector).inner_text.gsub(/[[:space:]]/, " ").gsub("  ", " ").strip
          artist_selector = "div > span.artist_name"
          artist = el.at_css(artist_selector).inner_text.gsub(/[[:space:]]/, " ").gsub("  ", " ").strip
          producer_selector = "div > span.producer_name"
          producer = el.at_css(producer_selector).inner_text.gsub("配信ユーザー:", "").squish
          delivery_status_selector = "div > span.delivery_status"
          delivery_status = el.at_css(delivery_status_selector).inner_text.gsub("配信期限:", "").squish
          delivery_deadline_on = Date.parse(delivery_status)
          record = find_or_initialize_by(title:, artist:, producer:, url: music_post_url)
          record.delivery_deadline_on = delivery_deadline_on
          record.save! if record.new_record? || record.changed?
          processed_count += 1

          next unless ((index + 1) % 10).zero? || index + 1 == blocks.size

          progress&.call(
            percentage: unknown_page_progress(page, index + 1, blocks.size, progress_range),
            status: "ミュージックポスト取得中",
            label:,
            detail: "処理済み: #{processed_count}件 / #{page}ページ目",
            current: processed_count,
            total: nil
          )
        end
        nav_selector = "#pager_bottom > div > a"
        next_link = nil
        browser.css(nav_selector).each do |el|
          next_box = el.at_css("span.next_page.page.box")&.inner_text
          next_link = el if next_box&.start_with?("次へ")
        end

        break if next_link.blank?

        next_link.focus.click
        page += 1
      end
    end
    browser.quit
  rescue Ferrum::TimeoutError => e
    logger.error("self.music_post_parser: #{e}")
    browser.quit
    browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
    retry_count += 1
    retry unless retry_count > 3
  end

  def self.progress_percentage(current, total)
    return 96 if total.to_i.zero?

    (8 + (88 * (current.to_f / total))).floor.clamp(8, 96)
  end

  def self.unknown_page_progress(page, item_index, item_count, progress_range)
    item_fraction = item_count.positive? ? item_index.to_f / item_count : 0.0
    ratio = ((page - 1) + item_fraction) / (page + 1).to_f
    start_percentage = progress_range.begin
    finish_percentage = progress_range.end

    (start_percentage + ((finish_percentage - start_percentage) * ratio)).floor.clamp(start_percentage, finish_percentage)
  end
end
