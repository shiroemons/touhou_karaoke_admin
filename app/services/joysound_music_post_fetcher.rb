class JoysoundMusicPostFetcher
  class << self
    def fetch_music_post(progress: nil)
      url_zun = Constants::Karaoke::Joysound::MUSIC_POST_ZUN_URL
      url_u2 = Constants::Karaoke::Joysound::MUSIC_POST_AKIYAMA_URL

      music_post_parser(url_zun, progress:, progress_range: 8..52, label: "ZUN楽曲のミュージックポストを取得しています")
      music_post_parser(url_u2, progress:, progress_range: 52..96, label: "あきやまうに楽曲のミュージックポストを取得しています")
    end

    def fetch_music_post_song_joysound_url(progress: nil)
      browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 2000], browser_options: { 'no-sandbox': nil })
      search_option = "?sortOrder=new&orderBy=desc&startIndex=0#songList"

      artist_names = JoysoundMusicPost.where(joysound_url: [nil, ""]).distinct.pluck(:artist)
      display_artists = DisplayArtist.music_post.where(name: artist_names)
      total_count = display_artists.count
      reporter = progress_reporter(
        progress:,
        status: "JOYSOUND URL取得中",
        label: "ミュージックポストのJOYSOUND URLを検索しています",
        unit: "アーティスト"
      )
      display_artists.each.with_index(1) do |display_artist, index|
        reporter&.advance(current: index - 1, total: total_count, force: true)
        url = display_artist.url + search_option
        browser.goto(url)
        sleep(1.0)

        loop do
          joysound_song_links(browser).each do |link|
            title = joysound_song_link_title(link)
            record = JoysoundMusicPost.find_by(artist: display_artist.name, title:)
            next unless record

            record.joysound_url = absolute_joysound_url(link.attribute("href").to_s)
            record.save! if record.changed?
          end

          next_link = joysound_artist_next_song_list_link(browser)
          break unless next_link

          next_link.focus.click
          sleep(1.0)
        end
        reporter&.advance(current: index, total: total_count, force: true)
      end
    rescue StandardError => e
      Rails.logger.error(e)
      browser.screenshot(path: "tmp/music_post.png")
    ensure
      browser&.quit
    end

    def music_post_parser(url, progress: nil, progress_range: 8..96, label: "ミュージックポストを取得しています")
      retry_count = 0
      page = 1
      processed_count = 0

      loop do
        browser = Ferrum::Browser.new(timeout: 30, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
        begin
          browser.goto(url)
          browser.network.wait_for_idle(duration: 1.0)
          loop do
            music_block_selector = "#box_music_list_bottom > div.music_block"
            blocks = browser.css(music_block_selector)

            Admin::ProgressReporter.report(
              progress:,
              percentage: unknown_page_progress(page, 0, blocks.size, progress_range),
              status: "ミュージックポスト取得中",
              label:,
              detail: "処理済み: #{processed_count}件 / #{page}ページ目",
              current: processed_count,
              total: nil
            )
            blocks.each_with_index do |element, index|
              save_music_post_entry(element)
              processed_count += 1

              next unless ((index + 1) % 10).zero? || index + 1 == blocks.size

              Admin::ProgressReporter.report(
                progress:,
                percentage: unknown_page_progress(page, index + 1, blocks.size, progress_range),
                status: "ミュージックポスト取得中",
                label:,
                detail: "処理済み: #{processed_count}件 / #{page}ページ目",
                current: processed_count,
                total: nil
              )
            end
            next_link = music_post_next_page_link(browser)
            break if next_link.blank?

            next_link.focus.click
            page += 1
          end
          break
        rescue Ferrum::TimeoutError => e
          Rails.logger.error("self.music_post_parser: #{e}")
          retry_count += 1
          break if retry_count > 3
        ensure
          browser&.quit
        end
      end
    end

    def progress_percentage(current, total)
      Admin::ProgressReporter.percentage(current, total)
    end

    def progress_reporter(progress:, status:, label:, unit: "件")
      return unless progress

      Admin::ProgressReporter.new(progress:, status:, label:, unit:)
    end

    def unknown_page_progress(page, item_index, item_count, progress_range)
      item_fraction = item_count.positive? ? item_index.to_f / item_count : 0.0
      ratio = ((page - 1) + item_fraction) / (page + 1).to_f
      start_percentage = progress_range.begin
      finish_percentage = progress_range.end

      (start_percentage + ((finish_percentage - start_percentage) * ratio)).floor.clamp(start_percentage, finish_percentage)
    end

    def joysound_song_links(browser)
      browser.css('#songList [data-testid="card-information"] a[href^="/web/search/song/"]')
    end

    def joysound_song_link_title(link)
      display_title = link.css("h3, p")
                          .map { |node| node.inner_text.to_s.squish }
                          .find(&:present?)
      display_title ||= link.inner_text.to_s.squish

      display_title.split("／").first.to_s.squish
    end

    def joysound_artist_next_song_list_link(browser)
      browser.css('#songList a[href*="page="]').find do |link|
        link.inner_text.to_s.include?("次") || link.attribute("href").to_s.include?("#songList")
      end
    end

    def absolute_joysound_url(path)
      URI.join(Constants::Karaoke::Joysound::BASE_URL, path).to_s
    end

    private

    def save_music_post_entry(element)
      music_post_url = element.at_css("a").property("href")

      title = element.at_css("div > span.music_name").inner_text.gsub(/[[:space:]]/, " ").gsub("  ", " ").strip
      artist = element.at_css("div > span.artist_name").inner_text.gsub(/[[:space:]]/, " ").gsub("  ", " ").strip
      producer = element.at_css("div > span.producer_name").inner_text.gsub("配信ユーザー:", "").squish
      delivery_status = element.at_css("div > span.delivery_status").inner_text.gsub("配信期限:", "").squish
      delivery_deadline_on = Date.parse(delivery_status)
      record = JoysoundMusicPost.find_or_initialize_by(title:, artist:, producer:, url: music_post_url)
      record.delivery_deadline_on = delivery_deadline_on
      record.save! if record.new_record? || record.changed?
    end

    def music_post_next_page_link(browser)
      nav_selector = "#pager_bottom > div > a"
      browser.css(nav_selector).find do |element|
        element.at_css("span.next_page.page.box")&.inner_text&.start_with?("次へ")
      end
    end
  end
end
