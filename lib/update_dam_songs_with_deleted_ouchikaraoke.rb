# frozen_string_literal: true

# DAMおうちカラオケURL削除楽曲の配信機種更新スクリプト
#
# check_algolia_upload.rb で検出したおうちカラオケURL削除対象のDAM楽曲に対して、
# 配信機種を更新する
#
# Usage:
#   bin/rails runner lib/update_dam_songs_with_deleted_ouchikaraoke.rb [OPTIONS]
#
# Options:
#   --dry-run    実際の更新を行わず、対象楽曲のみ表示
#   -h, --help   ヘルプを表示
#
# 必要な環境変数:
#   ALGOLIA_APPLICATION_ID  - Algolia Application ID
#   ALGOLIA_API_KEY         - Browse権限を持つAPI Key
#   ALGOLIA_INDEX_NAME      - インデックス名 (例: touhou_karaoke)

require "json"
require "algolia"
require "optparse"

# ============================================================
# 設定
# ============================================================
ALGOLIA_APP_ID = ENV.fetch("ALGOLIA_APPLICATION_ID", nil)
ALGOLIA_API_KEY = ENV.fetch("ALGOLIA_API_KEY", nil)
ALGOLIA_INDEX_NAME = ENV.fetch("ALGOLIA_INDEX_NAME", "touhou_karaoke")
LOCAL_JSON_PATH = "tmp/karaoke_songs.json"

# ============================================================
# URL削除警告対象フィールド
# ============================================================
URL_DELETION_WARNING_FIELDS = %w[
  url
  ouchikaraoke_url
  musicpost_url
  display_artist.url
].freeze

# ============================================================
# Algoliaレコード比較ヘルパー
# ============================================================
module AlgoliaRecordComparator
  module_function

  def deep_diff(old_value, new_value, path = "")
    differences = []

    case new_value
    when Hash
      differences.concat(diff_hash(old_value, new_value, path))
    when Array
      differences << { path: path, old: old_value, new: new_value } if array_changed?(old_value, new_value)
    else
      differences << { path: path, old: old_value, new: new_value } if old_value != new_value
    end

    differences
  end

  def diff_hash(old_value, new_value, path)
    return [{ path: path, old: old_value, new: new_value }] unless old_value.is_a?(Hash)

    all_keys = (old_value.keys + new_value.keys).map(&:to_s).uniq
    all_keys.flat_map do |key|
      new_path = path.empty? ? key : "#{path}.#{key}"
      old_val = old_value[key] || old_value[key.to_sym]
      new_val = new_value[key] || new_value[key.to_sym]
      deep_diff(old_val, new_val, new_path)
    end
  end

  def array_changed?(old_value, new_value)
    normalize_array(old_value).to_json != normalize_array(new_value).to_json
  end

  def normalize_value(value)
    case value
    when Hash
      value.transform_keys(&:to_s).sort.to_h.transform_values { |v| normalize_value(v) }
    when Array
      normalize_array(value)
    else
      value
    end
  end

  def normalize_array(arr)
    return arr unless arr.is_a?(Array)

    arr.map { |item| normalize_value(item) }.sort_by(&:to_json)
  end

  def detect_url_deletions(differences)
    differences.select do |diff|
      URL_DELETION_WARNING_FIELDS.include?(diff[:path]) && !diff[:old].nil? && diff[:new].nil?
    end
  end
end

# ============================================================
# モジュール定義
# ============================================================
# rubocop:disable Metrics/ModuleLength
module UpdateDamSongsWithDeletedOuchikaraoke
  extend self

  def run(dry_run: false)
    puts "=== DAMおうちカラオケURL削除楽曲の配信機種更新 ==="
    puts ""

    validate_environment!
    target_songs = find_target_songs

    if target_songs.empty?
      puts "対象楽曲はありません。"
      return
    end

    puts "対象楽曲: #{target_songs.count} 件"
    puts ""

    if dry_run
      display_dry_run_results(target_songs)
    else
      update_delivery_models(target_songs)
    end
  end

  private

  def validate_environment!
    missing = []
    missing << "ALGOLIA_APPLICATION_ID" if ALGOLIA_APP_ID.blank?
    missing << "ALGOLIA_API_KEY" if ALGOLIA_API_KEY.blank?

    return if missing.empty?

    warn "エラー: 必要な環境変数が設定されていません: #{missing.join(', ')}"
    exit 1
  end

  def find_target_songs
    puts "ローカルJSONファイルを読み込み中..."
    local_records = load_local_json(LOCAL_JSON_PATH)
    puts "  -> #{local_records.size} 件のレコードを読み込みました"

    puts "Algoliaからレコード取得中..."
    algolia_records = fetch_algolia_records
    puts "  -> #{algolia_records.size} 件のレコードを取得しました"

    puts "レコードを比較中..."
    results = compare_records(local_records, algolia_records)

    url_deletions = aggregate_url_deletions(results[:updated])
    target_ids = url_deletions.select { |w| w[:field] == "ouchikaraoke_url" }.pluck(:id)

    puts "  -> おうちカラオケURL削除対象: #{target_ids.size} 件"
    puts ""

    Song.dam.where(id: target_ids).includes(:karaoke_delivery_models, :display_artist)
  end

  def load_local_json(path)
    unless File.exist?(path)
      warn "エラー: ローカルJSONファイルが見つかりません: #{path}"
      warn "  -> bin/rails runner lib/export_songs.rb を実行してください"
      exit 1
    end

    JSON.parse(File.read(path))
  rescue JSON::ParserError => e
    warn "エラー: JSONパースエラー: #{e.message}"
    exit 1
  end

  def fetch_algolia_records
    client = Algolia::SearchClient.create(ALGOLIA_APP_ID, ALGOLIA_API_KEY)
    records = []

    client.browse_objects(ALGOLIA_INDEX_NAME, { attributesToRetrieve: ["*"] }).each do |record|
      props = record.additional_properties
      record_hash = { "objectID" => record.algolia_object_id }
      props.each { |key, value| record_hash[key.to_s] = value }
      records << record_hash
    end

    records
  end

  def compare_records(local_records, algolia_records)
    local_by_id = local_records.index_by { |r| r["objectID"] }
    algolia_by_id = algolia_records.index_by { |r| r["objectID"] }

    common_ids = Set.new(local_by_id.keys) & Set.new(algolia_by_id.keys)
    updated_records = common_ids.filter_map do |id|
      differences = AlgoliaRecordComparator.deep_diff(algolia_by_id[id], local_by_id[id])
      next if differences.empty?

      {
        "objectID" => id,
        "title" => local_by_id[id]["title"],
        "url_deletions" => AlgoliaRecordComparator.detect_url_deletions(differences)
      }
    end

    { updated: updated_records }
  end

  def aggregate_url_deletions(updated_records)
    updated_records.flat_map do |record|
      (record[:url_deletions] || record["url_deletions"] || []).map do |deletion|
        { id: record[:id] || record["objectID"], field: deletion[:path] }
      end
    end
  end

  def display_dry_run_results(target_songs)
    puts "[DRY-RUN] 以下の楽曲が対象です:"
    target_songs.each do |song|
      puts "  - [#{song.id}] #{song.title} (#{song.display_artist.name})"
    end
  end

  def update_delivery_models(songs)
    scraper = Scrapers::DamScraper.new
    total = songs.count
    success_count = 0
    error_count = 0

    songs.each_with_index do |song, index|
      puts "[#{index + 1}/#{total}] #{song.title} (#{song.display_artist.name})"

      begin
        scraper.update_delivery_models(song)
        success_count += 1
      rescue StandardError => e
        error_count += 1
        puts "  エラー: #{e.message}"
      end
    end

    display_summary(success_count, error_count)
  end

  def display_summary(success_count, error_count)
    puts ""
    puts "=== 結果サマリー ==="
    puts "成功: #{success_count} 件"
    puts "エラー: #{error_count} 件" if error_count.positive?
    puts "完了しました。"
  end
end
# rubocop:enable Metrics/ModuleLength

# ============================================================
# メイン処理
# ============================================================
if __FILE__ == $PROGRAM_NAME || defined?(Rails::Console)
  options = { dry_run: false }

  OptionParser.new do |opts|
    opts.banner = "Usage: bin/rails runner lib/update_dam_songs_with_deleted_ouchikaraoke.rb [OPTIONS]"

    opts.on("--dry-run", "実際の更新を行わず、対象楽曲のみ表示") do
      options[:dry_run] = true
    end

    opts.on("-h", "--help", "ヘルプを表示") do
      puts opts
      exit
    end
  end.parse!(ARGV)

  UpdateDamSongsWithDeletedOuchikaraoke.run(**options)
end
