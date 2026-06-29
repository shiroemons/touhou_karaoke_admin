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
    Scrapers::DamArtistScraper.new.scrape_artist_page(url)
  end

  def self.progress_percentage(current, total)
    return 96 if total.to_i.zero?

    (8 + (88 * (current.to_f / total))).floor.clamp(8, 96)
  end
end
