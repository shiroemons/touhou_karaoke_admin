# frozen_string_literal: true

# Algolia アップロード Dry-Run スクリプト
#
# tmp/karaoke_songs.json とAlgoliaインデックスを比較し、
# 新規追加/削除/更新レコードを検出する
#
# Usage:
#   bin/rails runner lib/check_algolia_upload.rb [OPTIONS]
#
# Options:
#   --json                   JSON形式で出力
#   --verbose                詳細表示
#   --output-changes FILE    変更があるレコードのみをFILEに出力
#   --no-color               カラー出力を無効化
#
# 必要な環境変数:
#   ALGOLIA_APPLICATION_ID  - Algolia Application ID
#   ALGOLIA_API_KEY         - Browse権限を持つAPI Key
#   ALGOLIA_INDEX_NAME      - インデックス名 (例: touhou_karaoke)

require "json"
require "algolia"
require "optparse"

# ============================================================
# ANSIカラーコード
# ============================================================
module Colors
  RESET = "\e[0m"
  BOLD = "\e[1m"
  RED = "\e[31m"
  GREEN = "\e[32m"
  YELLOW = "\e[33m"
  CYAN = "\e[36m"
  GRAY = "\e[90m"

  class << self
    attr_accessor :enabled

    def colorize(text, *codes)
      return text unless enabled

      "#{codes.join}#{text}#{RESET}"
    end

    def bold(text)
      colorize(text, BOLD)
    end

    def red(text)
      colorize(text, RED)
    end

    def green(text)
      colorize(text, GREEN)
    end

    def yellow(text)
      colorize(text, YELLOW)
    end

    def cyan(text)
      colorize(text, CYAN)
    end

    def gray(text)
      colorize(text, GRAY)
    end
  end

  # デフォルトで有効
  self.enabled = true
end

# ============================================================
# コマンドラインオプション解析
# ============================================================
options = {
  json: false,
  verbose: false,
  show_unchanged: false,
  output_changes: nil,
  color: true
}

OptionParser.new do |opts|
  opts.banner = "Usage: bin/rails runner lib/check_algolia_upload.rb [OPTIONS]"

  opts.on("--json", "JSON形式で出力") do
    options[:json] = true
  end

  opts.on("--verbose", "詳細表示") do
    options[:verbose] = true
  end

  opts.on("--show-unchanged", "変更なしレコードのIDを出力") do
    options[:show_unchanged] = true
  end

  opts.on("--output-changes FILE", "変更があるレコードのみをFILEに出力") do |file|
    options[:output_changes] = file
  end

  opts.on("--no-color", "カラー出力を無効化") do
    options[:color] = false
  end

  opts.on("-h", "--help", "ヘルプを表示") do
    puts opts
    exit
  end
end.parse!

# JSON出力時または--no-color指定時はカラーを無効化
Colors.enabled = options[:color] && !options[:json]

# ============================================================
# 設定
# ============================================================
ALGOLIA_APP_ID = ENV.fetch("ALGOLIA_APPLICATION_ID", nil)
ALGOLIA_API_KEY = ENV.fetch("ALGOLIA_API_KEY", nil)
ALGOLIA_INDEX_NAME = ENV.fetch("ALGOLIA_INDEX_NAME", "touhou_karaoke")
LOCAL_JSON_PATH = "tmp/karaoke_songs.json"

# ============================================================
# 環境変数チェック
# ============================================================
def validate_environment!
  missing = []
  missing << "ALGOLIA_APPLICATION_ID" if ALGOLIA_APP_ID.blank?
  missing << "ALGOLIA_API_KEY" if ALGOLIA_API_KEY.blank?

  return if missing.empty?

  warn "エラー: 必要な環境変数が設定されていません: #{missing.join(', ')}"
  exit 1
end

# ============================================================
# 比較時に無視するフィールド（特定のパス配下）
# ============================================================
IGNORE_FIELDS = {
  "karaoke_delivery_models" => ["karaoke_type"] # nameのみで比較
}.freeze

# ============================================================
# フィールド名の日本語マッピング
# ============================================================
FIELD_LABELS = {
  "delivery_deadline_date" => "配信期限日",
  "delivery_deadline_date_i" => "配信期限日(Unix)",
  "karaoke_delivery_models" => "配信機種",
  "updated_at_i" => "更新日時(Unix)",
  "touhou_music" => "音楽配信リンク",
  "ouchikaraoke_url" => "おうちカラオケURL",
  "display_artist.url" => "アーティストURL",
  "display_artist.name" => "アーティスト名",
  "display_artist.reading_name" => "アーティスト名(カナ)",
  "display_artist.reading_name_hiragana" => "アーティスト名(ひらがな)",
  "display_artist.karaoke_type" => "カラオケ種別",
  "videos" => "動画リンク",
  "circle.name" => "サークル名",
  "original_songs" => "原曲",
  "title" => "タイトル",
  "reading_title" => "タイトル(カナ)",
  "url" => "URL",
  "song_number" => "曲番号",
  "musicpost_url" => "Music Post URL"
}.freeze

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
# URL削除（値→nil変化）を検出
# @param differences [Array<Hash>] 差分配列
# @return [Array<Hash>] URL削除のある差分のみ
# ============================================================
def detect_url_deletions(differences)
  differences.select do |diff|
    URL_DELETION_WARNING_FIELDS.include?(diff[:path]) &&
      !diff[:old].nil? &&
      diff[:new].nil?
  end
end

# ============================================================
# URL追加（nil→値変化）を検出
# @param differences [Array<Hash>] 差分配列
# @return [Array<Hash>] URL追加のある差分のみ
# ============================================================
def detect_url_additions(differences)
  differences.select do |diff|
    URL_DELETION_WARNING_FIELDS.include?(diff[:path]) &&
      diff[:old].nil? &&
      !diff[:new].nil?
  end
end

# ============================================================
# URL更新（値→別の値変化）を検出
# @param differences [Array<Hash>] 差分配列
# @return [Array<Hash>] URL更新のある差分のみ
# ============================================================
def detect_url_updates(differences)
  differences.select do |diff|
    URL_DELETION_WARNING_FIELDS.include?(diff[:path]) &&
      !diff[:old].nil? &&
      !diff[:new].nil?
  end
end

# ============================================================
# 全レコードからURL削除を集計
# @param updated_records [Array<Hash>] 更新レコード配列
# @return [Array<Hash>] URL削除警告リスト
# ============================================================
def aggregate_url_deletions(updated_records)
  updated_records.flat_map do |record|
    (record[:url_deletions] || record["url_deletions"] || []).map do |deletion|
      {
        id: record[:id] || record["objectID"],
        title: record[:title] || record["title"],
        field: deletion[:path],
        old_value: deletion[:old]
      }
    end
  end
end

# ============================================================
# 全レコードからURL追加を集計
# @param updated_records [Array<Hash>] 更新レコード配列
# @return [Array<Hash>] URL追加リスト
# ============================================================
def aggregate_url_additions(updated_records)
  updated_records.flat_map do |record|
    (record[:url_additions] || record["url_additions"] || []).map do |addition|
      {
        id: record[:id] || record["objectID"],
        title: record[:title] || record["title"],
        field: addition[:path],
        new_value: addition[:new]
      }
    end
  end
end

# ============================================================
# URL削除をフィールド別に集計
# @param url_deletions [Array<Hash>] URL削除リスト
# @return [Hash<String, Integer>] フィールド => 件数
# ============================================================
def count_url_deletions_by_field(url_deletions)
  url_deletions.group_by { |d| d[:field] }
               .transform_values(&:count)
end

# ============================================================
# URL追加をフィールド別に集計
# @param url_additions [Array<Hash>] URL追加リスト
# @return [Hash<String, Integer>] フィールド => 件数
# ============================================================
def count_url_additions_by_field(url_additions)
  url_additions.group_by { |a| a[:field] }
               .transform_values(&:count)
end

# ============================================================
# 全レコードからURL更新を集計
# @param updated_records [Array<Hash>] 更新レコード配列
# @return [Array<Hash>] URL更新リスト
# ============================================================
def aggregate_url_updates(updated_records)
  updated_records.flat_map do |record|
    (record[:url_updates] || record["url_updates"] || []).map do |update|
      {
        id: record[:id] || record["objectID"],
        title: record[:title] || record["title"],
        field: update[:path],
        old_value: update[:old],
        new_value: update[:new]
      }
    end
  end
end

# ============================================================
# URL更新をフィールド別に集計
# @param url_updates [Array<Hash>] URL更新リスト
# @return [Hash<String, Integer>] フィールド => 件数
# ============================================================
def count_url_updates_by_field(url_updates)
  url_updates.group_by { |u| u[:field] }
             .transform_values(&:count)
end

# ============================================================
# フィールド名を日本語ラベルに変換
# ============================================================
def field_to_label(field)
  FIELD_LABELS.fetch(field, field)
end

# ============================================================
# 表示幅計算ヘルパー（全角=2, 半角=1）
# ============================================================

# 文字列の表示幅を計算
def display_width(str)
  str.each_char.sum do |char|
    char.bytesize > 1 ? 2 : 1
  end
end

# 表示幅を考慮した左寄せ
def ljust_display(str, width)
  str + (" " * [width - display_width(str), 0].max)
end

# 表示幅を考慮した右寄せ
def rjust_display(str, width)
  (" " * [width - display_width(str), 0].max) + str
end

# ============================================================
# 差分表示用の値フォーマット（ハッシュ形式を統一）
# ============================================================
def format_value(value)
  case value
  when Hash, Array
    JSON.generate(value)
  else
    value.inspect
  end
end

# ============================================================
# 配列要素から識別キーを抽出
# ============================================================
def extract_keys(arr)
  arr.map do |item|
    if item.is_a?(Hash)
      item["name"] || item[:name] || item["type"] || item[:type] || item.to_json
    else
      item.to_s
    end
  end
end

# ============================================================
# 配列の差分を追加/削除形式でフォーマット
# ============================================================
def format_array_diff(label, old_arr, new_arr)
  old_keys = extract_keys(old_arr)
  new_keys = extract_keys(new_arr)

  added = new_keys - old_keys
  removed = old_keys - new_keys

  lines = ["        変更: #{Colors.cyan(label)}"]
  lines << "          #{Colors.green('追加:')} #{added.join(', ')}" if added.any?
  lines << "          #{Colors.red('削除:')} #{removed.join(', ')}" if removed.any?

  # 追加も削除もない場合（順序変更のみなど）
  lines << "          (順序変更のみ)" if added.empty? && removed.empty?

  lines.join("\n")
end

# ============================================================
# スカラー値の差分をフォーマット
# ============================================================
def format_scalar_diff(label, old_val, new_val)
  "        変更: #{Colors.cyan(label)}\n          #{Colors.red('旧:')} #{format_value(old_val)}\n          #{Colors.green('新:')} #{format_value(new_val)}"
end

# ============================================================
# 差分を見やすくフォーマット
# ============================================================
def format_diff(diff)
  old_val = diff[:old]
  new_val = diff[:new]
  path = diff[:path]
  label = field_to_label(path)

  if old_val.is_a?(Array) && new_val.is_a?(Array)
    format_array_diff(label, old_val, new_val)
  else
    format_scalar_diff(label, old_val, new_val)
  end
end

# ============================================================
# 配列正規化関数（順序無視の比較のため）
# ============================================================
def normalize_array(arr, path = "")
  return arr unless arr.is_a?(Array)

  arr.map { |item| normalize_value(item, path) }.sort_by(&:to_json)
end

def normalize_value(value, path = "")
  case value
  when Hash
    # 特定のパスでは指定フィールドを除外
    filtered = value.transform_keys(&:to_s)
    IGNORE_FIELDS.each do |target_path, fields|
      fields.each { |f| filtered.delete(f) } if path == target_path || path.end_with?(".#{target_path}")
    end
    filtered.sort
            .to_h
            .transform_values { |v| normalize_value(v, path) }
  when Array
    normalize_array(value, path)
  else
    value
  end
end

# ============================================================
# 深い比較関数（配列順序無視）
# old_value: Algolia（現在の値）
# new_value: local（アップロードする新しい値）
# ============================================================
def deep_diff(old_value, new_value, path = "")
  differences = []

  # 両方をまず正規化してから比較（パスを渡して特定フィールドを除外）
  normalized_old = normalize_value(old_value, path)
  normalized_new = normalize_value(new_value, path)

  case new_value
  when Hash
    if old_value.is_a?(Hash)
      # 両方がHashの場合、キーを文字列に統一して全キーを取得
      old_keys = old_value.keys.map(&:to_s)
      new_keys = new_value.keys.map(&:to_s)
      all_keys = (old_keys + new_keys).uniq

      all_keys.each do |key|
        new_path = path.empty? ? key : "#{path}.#{key}"
        old_val = old_value[key] || old_value[key.to_sym]
        new_val = new_value[key] || new_value[key.to_sym]
        differences.concat(deep_diff(old_val, new_val, new_path))
      end
    elsif normalized_old != normalized_new
      # old_valueがHashでない場合は単純比較
      differences << { path: path, old: old_value, new: new_value }
    end
  when Array
    # 配列は正規化後のJSON文字列で比較（より確実）
    differences << { path: path, old: old_value, new: new_value } if normalized_old.to_json != normalized_new.to_json
  else
    differences << { path: path, old: old_value, new: new_value } if old_value != new_value
  end

  differences
end

# ============================================================
# ローカルJSONファイル読み込み
# ============================================================
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

# ============================================================
# Algoliaからレコード取得 (Browse API)
# ============================================================
def fetch_algolia_records(client, verbose: false)
  records = []
  count = 0

  client.browse_objects(
    ALGOLIA_INDEX_NAME,
    {
      attributesToRetrieve: ["*"]
    }
  ).each do |record|
    count += 1
    print "\rAlgoliaからレコード取得中... #{count}件" if verbose

    props = record.additional_properties
    record_hash = { "objectID" => record.algolia_object_id }
    props.each do |key, value|
      record_hash[key.to_s] = value
    end
    records << record_hash
  end

  puts if verbose
  records
end

# ============================================================
# レコードの比較
# ※ローカルJSONは更新対象のみを含む（全件ではない）
# ============================================================
def compare_records(local_records, algolia_records)
  local_by_id = local_records.index_by { |r| r["objectID"] }
  algolia_by_id = algolia_records.index_by { |r| r["objectID"] }

  local_ids = Set.new(local_by_id.keys)
  algolia_ids = Set.new(algolia_by_id.keys)

  # 新規追加（ローカルにあってAlgoliaにない）
  new_ids = local_ids - algolia_ids
  new_records = new_ids.map { |id| local_by_id[id] }

  # 更新（両方にあるが内容が異なる）/ 変更なし
  common_ids = local_ids & algolia_ids
  updated_records = []
  unchanged_records = []

  common_ids.each do |id|
    local_record = local_by_id[id]
    algolia_record = algolia_by_id[id]

    # deep_diff(old, new) = deep_diff(algolia, local)
    # old = Algolia（現在の値）、new = local（アップロードする新しい値）
    differences = deep_diff(algolia_record, local_record)
    if differences.empty?
      unchanged_records << {
        "objectID" => id,
        "title" => local_record["title"]
      }
      next
    end

    updated_records << {
      "objectID" => id,
      "title" => local_record["title"],
      "differences" => differences,
      "url_deletions" => detect_url_deletions(differences),
      "url_additions" => detect_url_additions(differences),
      "url_updates" => detect_url_updates(differences)
    }
  end

  {
    new: new_records,
    updated: updated_records,
    unchanged: unchanged_records
  }
end

# ============================================================
# 更新フィールドの集計（日本語ラベル変換済み）
# ============================================================
def aggregate_updated_fields(updated_records)
  field_counts = Hash.new(0)

  updated_records.each do |record|
    record["differences"].each do |diff|
      # フィールド名を日本語ラベルに変換
      label = field_to_label(diff[:path])
      field_counts[label] += 1
    end
  end

  # 件数の多い順にソート
  field_counts.sort_by { |_field, count| -count }
end

# ============================================================
# 配列要素から比較用キーを抽出
# @param arr [Array] 配列
# @return [Set] キーのセット
# ============================================================
def extract_array_keys_for_comparison(arr)
  Array(arr).to_set do |item|
    if item.is_a?(Hash)
      item["name"] || item[:name] || item["type"] || item[:type] || item.to_json
    else
      item.to_s
    end
  end
end

# ============================================================
# 全フィールドの変更を集計
# @param updated_records [Array<Hash>] 更新レコード配列
# @return [Hash<String, Hash>] フィールド => { total:, additions:, updates:, deletions: }
# ============================================================
def aggregate_all_field_changes(updated_records)
  result = Hash.new { |h, k| h[k] = { total: 0, additions: 0, updates: 0, deletions: 0 } }

  updated_records.each do |record|
    differences = record["differences"] || record[:differences] || []
    differences.each do |diff|
      field = diff[:path] || diff["path"]
      old_val = diff[:old] || diff["old"]
      new_val = diff[:new] || diff["new"]

      # 配列フィールドの場合、要素単位でカウント
      if old_val.is_a?(Array) || new_val.is_a?(Array)
        old_set = extract_array_keys_for_comparison(old_val)
        new_set = extract_array_keys_for_comparison(new_val)

        added = new_set - old_set
        removed = old_set - new_set

        result[field][:additions] += added.size
        result[field][:deletions] += removed.size
        result[field][:total] += added.size + removed.size
      else
        # 非配列フィールドは従来通り
        result[field][:total] += 1
        if old_val.nil? && !new_val.nil?
          result[field][:additions] += 1
        elsif !old_val.nil? && new_val.nil?
          result[field][:deletions] += 1
        else
          result[field][:updates] += 1
        end
      end
    end
  end

  result
end

# ============================================================
# テキスト形式出力
# ============================================================
def output_text(local_count:, algolia_count:, results:, verbose:, show_unchanged: false)
  new_records = results[:new]
  updated_records = results[:updated]
  unchanged_records = results[:unchanged]

  puts Colors.bold("=== Algolia アップロード Dry-Run レポート ===")
  puts ""
  puts Colors.bold("サマリー")
  puts "  ローカル JSON (更新対象): #{local_count} 件"
  puts "  Algolia (全件): #{algolia_count} 件"
  puts ""
  puts "  新規追加: #{Colors.green("#{new_records.size} 件")}"
  puts "  更新: #{Colors.yellow("#{updated_records.size} 件")}"
  puts "  変更なし: #{Colors.gray("#{unchanged_records.size} 件")}"
  puts ""

  # URL削除を集計（警告用）
  url_deletions = aggregate_url_deletions(updated_records)
  url_deletion_count = url_deletions.count

  # 更新内容の内訳を表示
  if updated_records.any?
    field_changes = aggregate_all_field_changes(updated_records)

    # 件数の多い順にソート
    sorted_fields = field_changes.sort_by { |_, stats| -stats[:total] }

    puts Colors.bold("=== 更新内容の内訳 ===")

    # 表のカラム幅を計算（表示幅ベース）
    header_label = "フィールド名"
    field_labels = sorted_fields.map { |f, _| field_to_label(f) }
    max_display_width = [
      field_labels.map { |l| display_width(l) }.max || 0,
      display_width(header_label),
      display_width("合計")
    ].max
    separator = "  #{'-' * max_display_width}|------|------|------|------"

    puts "  #{ljust_display(header_label, max_display_width)} | 件数 | 追加 | 更新 | 削除"
    puts separator

    total_all = 0
    total_additions = 0
    total_updates = 0
    total_deletions = 0

    sorted_fields.each do |field, stats|
      label = field_to_label(field)
      total_all += stats[:total]
      total_additions += stats[:additions]
      total_updates += stats[:updates]
      total_deletions += stats[:deletions]

      total_str = rjust_display(stats[:total].to_s, 4)
      add_str = rjust_display(stats[:additions].to_s, 4)
      upd_str = rjust_display(stats[:updates].to_s, 4)
      del_str = if stats[:deletions].positive?
                  Colors.red(rjust_display(stats[:deletions].to_s, 4))
                else
                  rjust_display(stats[:deletions].to_s, 4)
                end

      puts "  #{ljust_display(label, max_display_width)} | #{total_str} | #{add_str} | #{upd_str} | #{del_str}"
    end

    puts separator
    total_all_str = rjust_display(total_all.to_s, 4)
    total_add_str = rjust_display(total_additions.to_s, 4)
    total_upd_str = rjust_display(total_updates.to_s, 4)
    total_del_str = if total_deletions.positive?
                      Colors.red(rjust_display(total_deletions.to_s, 4))
                    else
                      rjust_display(total_deletions.to_s, 4)
                    end
    puts "  #{ljust_display('合計', max_display_width)} | #{total_all_str} | #{total_add_str} | #{total_upd_str} | #{total_del_str}"

    # URL削除がある場合は警告を表示
    if url_deletion_count.positive?
      puts ""
      puts "  #{Colors.colorize('⚠ URL削除警告あり（詳細は下記参照）', Colors::RED, Colors::BOLD)}"
    end
    puts ""
  end

  if new_records.any?
    puts Colors.bold("--- 新規追加 (#{new_records.size}件) ---")
    new_records.each do |record|
      puts "  #{Colors.green('[NEW]')} #{record['title']}"
      puts "        ID: #{record['objectID']}"
      puts "        URL: #{record['url']}"
      if verbose
        puts "        karaoke_type: #{record['karaoke_type']}"
        puts "        song_number: #{record['song_number']}" if record["song_number"]
      end
    end
    puts ""
  end

  if updated_records.any?
    puts Colors.bold("--- 更新 (#{updated_records.size}件) ---")
    updated_records.each do |record|
      puts "  #{Colors.yellow('[UPD]')} #{record['title']}"
      puts "        ID: #{record['objectID']}"
      if verbose
        record["differences"].each do |diff|
          puts format_diff(diff)
        end
      else
        paths = record["differences"].map { |d| Colors.cyan(d[:path]) }.join(", ")
        puts "        変更フィールド: #{paths}"
      end
    end
    puts ""
  end

  if show_unchanged && unchanged_records.any?
    puts Colors.bold("--- 変更なし (#{unchanged_records.size}件) ---")
    unchanged_records.each do |record|
      puts "  #{Colors.gray('[---]')} #{record['title']}"
      puts "        ID: #{record['objectID']}"
    end
    puts ""
  end

  # URL削除警告がある場合、詳細を出力
  if url_deletion_count.positive?
    puts ""
    puts Colors.colorize("=== URL削除警告 詳細 (#{url_deletion_count}件) ===", Colors::RED, Colors::BOLD)
    puts Colors.red("以下のURLフィールドが削除されます。DBレコード消失の可能性があります。")
    puts ""

    # 個別詳細
    url_deletions.each do |deletion|
      puts "    #{Colors.red('[DEL]')} #{deletion[:title]}"
      puts "          ID: #{deletion[:id]}"
      puts "          フィールド: #{field_to_label(deletion[:field])}"
      puts "          旧値: #{deletion[:old_value].inspect}"
      puts ""
    end
  end

  return unless new_records.empty? && updated_records.empty?

  puts "変更はありません。"
end

# ============================================================
# 変更があるレコードをファイルに出力
# ============================================================
def output_changes_to_file(file_path, local_records, results)
  local_by_id = local_records.index_by { |r| r["objectID"] }

  # 新規追加レコードのID
  new_ids = results[:new].pluck("objectID")

  # 更新レコードのID
  updated_ids = results[:updated].pluck("objectID")

  # 変更があるレコードのIDを取得
  changed_ids = new_ids + updated_ids

  # ローカルJSONの元データをフィルタリング
  changed_records = changed_ids.filter_map { |id| local_by_id[id] }

  # ファイルに出力
  File.write(file_path, JSON.pretty_generate(changed_records))

  changed_records.size
end

# ============================================================
# JSON形式出力
# ============================================================
def output_json(local_count:, algolia_count:, results:)
  url_deletions = aggregate_url_deletions(results[:updated])
  url_additions = aggregate_url_additions(results[:updated])
  url_updates = aggregate_url_updates(results[:updated])

  # 全フィールドの変更を集計
  field_changes = aggregate_all_field_changes(results[:updated])
  field_changes_output = field_changes.sort_by { |_, stats| -stats[:total] }.map do |field, stats|
    {
      field: field,
      field_label: field_to_label(field),
      total: stats[:total],
      additions: stats[:additions],
      updates: stats[:updates],
      deletions: stats[:deletions]
    }
  end

  output = {
    summary: {
      local_count: local_count,
      algolia_count: algolia_count,
      new_count: results[:new].size,
      updated_count: results[:updated].size,
      unchanged_count: results[:unchanged].size,
      url_addition_count: url_additions.count,
      url_update_count: url_updates.count,
      url_deletion_warning_count: url_deletions.count
    },
    field_changes: field_changes_output,
    new: results[:new].map { |r| { objectID: r["objectID"], title: r["title"], url: r["url"], karaoke_type: r["karaoke_type"] } },
    updated: results[:updated].map do |r|
      {
        objectID: r["objectID"],
        title: r["title"],
        differences: r["differences"].map { |d| { path: d[:path], old: d[:old], new: d[:new] } }
      }
    end,
    unchanged: results[:unchanged].map { |r| { objectID: r["objectID"], title: r["title"] } },
    url_additions: url_additions.map do |a|
      {
        id: a[:id],
        title: a[:title],
        field: a[:field],
        field_label: field_to_label(a[:field]),
        new_value: a[:new_value]
      }
    end,
    url_updates: url_updates.map do |u|
      {
        id: u[:id],
        title: u[:title],
        field: u[:field],
        field_label: field_to_label(u[:field]),
        old_value: u[:old_value],
        new_value: u[:new_value]
      }
    end,
    url_deletion_warnings: url_deletions.map do |d|
      {
        id: d[:id],
        title: d[:title],
        field: d[:field],
        field_label: field_to_label(d[:field]),
        old_value: d[:old_value]
      }
    end
  }

  puts JSON.pretty_generate(output)
end

# ============================================================
# メイン処理
# ============================================================
def main(options)
  validate_environment!

  # Algoliaクライアント初期化
  puts "Algoliaクライアントを初期化中..." if options[:verbose]
  client = Algolia::SearchClient.create(ALGOLIA_APP_ID, ALGOLIA_API_KEY)

  # ローカルJSONファイル読み込み
  puts "ローカルJSONファイルを読み込み中..." if options[:verbose]
  local_records = load_local_json(LOCAL_JSON_PATH)
  puts "  -> #{local_records.size} 件のレコードを読み込みました" if options[:verbose]

  # Algoliaからレコード取得
  algolia_records = fetch_algolia_records(client, verbose: options[:verbose])
  puts "  -> #{algolia_records.size} 件のレコードを取得しました" if options[:verbose]

  # レコード比較
  puts "レコードを比較中..." if options[:verbose]
  results = compare_records(local_records, algolia_records)

  # 変更があるレコードをファイルに出力
  if options[:output_changes]
    count = output_changes_to_file(options[:output_changes], local_records, results)
    puts "変更があるレコード #{count} 件を #{options[:output_changes]} に出力しました" if options[:verbose]
  end

  # 出力
  if options[:json]
    output_json(
      local_count: local_records.size,
      algolia_count: algolia_records.size,
      results: results
    )
  else
    output_text(
      local_count: local_records.size,
      algolia_count: algolia_records.size,
      results: results,
      verbose: options[:verbose],
      show_unchanged: options[:show_unchanged]
    )
  end
end

# スクリプト実行
main(options)
