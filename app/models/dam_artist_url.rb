class DamArtistUrl < ApplicationRecord
  validates :url, presence: true
  # Existing data can contain duplicates; keep this application guard until a non-destructive cleanup is complete.
  # rubocop:disable Rails/UniqueValidationWithoutIndex
  validates :url, uniqueness: true
  # rubocop:enable Rails/UniqueValidationWithoutIndex

  def self.ransackable_attributes(_auth_object = nil)
    ["url"]
  end

  def self.fetch_dam_artist(progress: nil)
    records = DamArtistUrl.all
    total_count = records.count
    records.find_each.with_index(1) do |dau, index|
      progress&.call(
        percentage: progress_percentage(index - 1, total_count),
        status: "DAMアーティスト取得中",
        label: "DAMアーティスト読みを取得しています",
        detail: "処理済み: #{index - 1}/#{total_count}件",
        current: index - 1,
        total: total_count
      )
      dam_artist_page_parser(dau.url) if DisplayArtist.exists?(karaoke_type: "DAM", url: dau.url, name_reading: "")
      progress&.call(
        percentage: progress_percentage(index, total_count),
        status: "DAMアーティスト取得中",
        label: "DAMアーティスト読みを取得しています",
        detail: "処理済み: #{index}/#{total_count}件",
        current: index,
        total: total_count
      )
    end
  end

  def self.fill_dam_artist_readings(progress: nil)
    fetch_dam_artist(progress:)
  end

  def self.dam_artist_page_parser(url)
    attempt = 0

    loop do
      attempt += 1
      browser = Ferrum::Browser.new(timeout: 10, window_size: [1440, 900], browser_options: { 'no-sandbox': nil })
      browser.goto(url)
      browser.network.wait_for_idle(duration: 1.0)
      name_selector = "#anchor-pagetop > main > div > div > div.main-content > div.artist-detail > h2.artist-name"
      name = browser.at_css(name_selector).inner_text
      name_reading_selector = "#anchor-pagetop > main > div > div > div.main-content > div.artist-detail > div.artist-yomi"
      name_reading = browser.at_css(name_reading_selector).inner_text.gsub(/[\[\] ]/, "")
      if name.present? && name_reading.present?
        record = DisplayArtist.find_or_initialize_by(karaoke_type: "DAM", url:)
        record.name = name
        record.name_reading = name_reading
        record.save! if record.changed?
      end
      break
    rescue StandardError => e
      logger.error(e)
      break if attempt > 3
    ensure
      browser&.quit
    end
  end

  def self.progress_percentage(current, total)
    return 96 if total.to_i.zero?

    (8 + (88 * (current.to_f / total))).floor.clamp(8, 96)
  end
end
