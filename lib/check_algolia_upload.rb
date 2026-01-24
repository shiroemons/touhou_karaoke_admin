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
# フィールド名を日本語ラベルに変換
# ============================================================
def field_to_label(field)
  FIELD_LABELS.fetch(field, field)
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
      "differences" => differences
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

  # 更新内容の内訳を表示
  if updated_records.any?
    field_counts = aggregate_updated_fields(updated_records)
    max_field_length = field_counts.map { |field, _| field.length }.max
    column_width = [max_field_length, 30].max

    puts Colors.bold("--- 更新内容の内訳 ---")
    puts format("  %-#{column_width}s | 件数", Colors.cyan("フィールド"))
    puts "  #{'-' * column_width}-|------"
    field_counts.each do |field, count|
      puts format("  %-#{column_width}s | %d", Colors.cyan(field), count)
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
  output = {
    summary: {
      local_count: local_count,
      algolia_count: algolia_count,
      new_count: results[:new].size,
      updated_count: results[:updated].size,
      unchanged_count: results[:unchanged].size
    },
    new: results[:new].map { |r| { objectID: r["objectID"], title: r["title"], url: r["url"], karaoke_type: r["karaoke_type"] } },
    updated: results[:updated].map do |r|
      {
        objectID: r["objectID"],
        title: r["title"],
        differences: r["differences"].map { |d| { path: d[:path], old: d[:old], new: d[:new] } }
      }
    end,
    unchanged: results[:unchanged].map { |r| { objectID: r["objectID"], title: r["title"] } }
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
