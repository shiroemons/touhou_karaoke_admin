# frozen_string_literal: true

# JOYSOUND(うたスキ) 配信期限切れレコードチェック・削除スクリプト
#
# Algoliaから JOYSOUND(うたスキ) の配信期限切れレコードを検出し、
# オプションで削除を実行する
#
# Usage:
#   bin/rails runner lib/check_expired_joysound_utasuki.rb [OPTIONS]
#
# Options:
#   --delete    実際に削除を実行（デフォルトは表示のみ）
#   --verify    URLにアクセスして配信終了を確認
#   --verbose   詳細表示
#   --json      JSON形式で出力
#   --no-color  カラー出力を無効化
#   -h, --help  ヘルプを表示
#
# 必要な環境変数:
#   ALGOLIA_APPLICATION_ID  - Algolia Application ID
#   ALGOLIA_API_KEY         - 削除権限を持つAPI Key
#   ALGOLIA_INDEX_NAME      - インデックス名 (例: touhou_karaoke)

require "algolia"
require "optparse"
require "json"

# rubocop:disable Metrics/ModuleLength
module CheckExpiredJoysoundUtasuki
  extend self

  # ============================================================
  # 設定
  # ============================================================
  ALGOLIA_APP_ID = ENV.fetch("ALGOLIA_APPLICATION_ID", nil)
  ALGOLIA_API_KEY = ENV.fetch("ALGOLIA_API_KEY", nil)
  ALGOLIA_INDEX_NAME = ENV.fetch("ALGOLIA_INDEX_NAME", "touhou_karaoke")

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
  # メイン処理
  # ============================================================
  def run(delete: false, verify: false, verbose: false, json: false, color: true)
    Colors.enabled = color && !json

    validate_environment!

    current_time = Time.zone.now
    client = Algolia::SearchClient.create(ALGOLIA_APP_ID, ALGOLIA_API_KEY)

    records = fetch_joysound_utasuki_records(client, verbose: verbose)
    expired_records = filter_expired_records(records, current_time)

    # URL検証オプションが有効な場合
    expired_records = verify_urls(expired_records, verbose: verbose) if verify && expired_records.any?

    if json
      output_json(expired_records, current_time, delete: delete, verify: verify)
    else
      output_text(expired_records, current_time, verbose: verbose, delete: delete, verify: verify)
    end

    return unless delete && expired_records.any?

    delete_expired_records(client, expired_records)
  end

  private

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
  # JOYSOUND(うたスキ) レコード取得
  # ============================================================
  def fetch_joysound_utasuki_records(client, verbose:)
    records = []
    count = 0

    client.browse_objects(
      ALGOLIA_INDEX_NAME,
      {
        filters: 'karaoke_type:"JOYSOUND(うたスキ)"',
        attributesToRetrieve: %w[objectID title display_artist delivery_deadline_date delivery_deadline_date_i url]
      }
    ).each do |record|
      count += 1
      print "\rJOYSOUND(うたスキ) レコード取得中... #{count}件" if verbose

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
  # 配信期限切れレコードのフィルタリング
  # ============================================================
  def filter_expired_records(records, current_time)
    current_timestamp = current_time.to_i

    records.select do |record|
      deadline_i = record["delivery_deadline_date_i"]
      deadline_i.present? && deadline_i < current_timestamp
    end
  end

  # ============================================================
  # URL検証（UrlCheckerサービスを使用）
  # ============================================================
  def verify_urls(records, verbose:)
    puts Colors.bold("URL検証中...")
    puts ""

    records.each_with_index do |record, index|
      url = record["url"]
      print "\r検証中... #{index + 1}/#{records.size}: #{truncate_title(record['title'].to_s, max_width: 30)}" if verbose

      if url.blank?
        record["url_status"] = "no_url"
        record["url_status_code"] = nil
        next
      end

      result = UrlChecker.check_url(url)

      if result[:exists] == false
        record["url_status"] = "not_found"
        record["url_status_code"] = result[:status_code]
      elsif result[:exists] == true
        record["url_status"] = "exists"
        record["url_status_code"] = result[:status_code]
      else
        record["url_status"] = "error"
        record["url_status_code"] = nil
        record["url_error"] = result[:error]
      end
    end

    puts if verbose
    puts ""

    records
  end

  # ============================================================
  # テキスト形式出力
  # ============================================================
  def output_text(expired_records, current_time, verbose:, delete:, verify: false)
    if delete
      puts Colors.bold("=== JOYSOUND(うたスキ) 配信期限切れ削除 ===")
    else
      puts Colors.bold("=== JOYSOUND(うたスキ) 配信期限切れチェック ===")
    end
    puts "現在時刻: #{current_time.strftime('%Y-%m-%d %H:%M:%S %z')}"
    puts ""

    if expired_records.empty?
      puts Colors.green("配信期限切れレコードはありません。")
      return
    end

    puts "配信期限切れレコード: #{Colors.red("#{expired_records.size}件")}"

    # URL検証結果のサマリー
    display_verification_summary(expired_records) if verify

    puts ""

    display_expired_records_table(expired_records, verbose: verbose, verify: verify)

    return if delete

    puts ""
    puts Colors.yellow("削除するには --delete オプションを指定してください")
    puts Colors.yellow("URL検証するには --verify オプションを指定してください") unless verify
  end

  # ============================================================
  # URL検証結果サマリー
  # ============================================================
  def display_verification_summary(records)
    not_found_count = records.count { |r| r["url_status"] == "not_found" }
    exists_count = records.count { |r| r["url_status"] == "exists" }
    error_count = records.count { |r| r["url_status"] == "error" }
    no_url_count = records.count { |r| r["url_status"] == "no_url" }

    puts ""
    puts Colors.bold("URL検証結果:")
    puts "  #{Colors.red("配信終了(404): #{not_found_count}件")}"
    puts "  #{Colors.green("まだ存在: #{exists_count}件")}"
    puts "  #{Colors.yellow("エラー: #{error_count}件")}" if error_count.positive?
    puts "  #{Colors.gray("URL無し: #{no_url_count}件")}" if no_url_count.positive?
  end

  # ============================================================
  # 期限切れレコードをテーブル形式で表示
  # ============================================================
  def display_expired_records_table(records, verbose:, verify: false)
    # カラム幅を計算
    id_header = "objectID"
    title_header = "タイトル"
    deadline_header = "配信期限"
    status_header = "URL状態"

    max_id_width = [display_width(id_header), records.map { |r| display_width(r["objectID"].to_s) }.max].max
    max_title_width = [display_width(title_header), records.map { |r| display_width(truncate_title(r["title"].to_s)) }.max].max
    max_deadline_width = [display_width(deadline_header), 10].max # YYYY/MM/DD
    max_status_width = 10 # 固定幅

    # ヘッダー
    if verify
      puts "| #{ljust_display(id_header, max_id_width)} | #{ljust_display(title_header, max_title_width)} | #{ljust_display(deadline_header, max_deadline_width)} | #{ljust_display(status_header, max_status_width)} |"
      puts "|#{'-' * (max_id_width + 2)}|#{'-' * (max_title_width + 2)}|#{'-' * (max_deadline_width + 2)}|#{'-' * (max_status_width + 2)}|"
    else
      puts "| #{ljust_display(id_header, max_id_width)} | #{ljust_display(title_header, max_title_width)} | #{ljust_display(deadline_header, max_deadline_width)} |"
      puts "|#{'-' * (max_id_width + 2)}|#{'-' * (max_title_width + 2)}|#{'-' * (max_deadline_width + 2)}|"
    end

    # データ行
    records.each do |record|
      object_id = record["objectID"].to_s
      title = truncate_title(record["title"].to_s)
      deadline = format_deadline(record["delivery_deadline_date"])

      if verify
        status = format_url_status(record)
        puts "| #{ljust_display(object_id, max_id_width)} | #{ljust_display(title, max_title_width)} | #{ljust_display(deadline, max_deadline_width)} | #{ljust_display(status, max_status_width)} |"
      else
        puts "| #{ljust_display(object_id, max_id_width)} | #{ljust_display(title, max_title_width)} | #{ljust_display(deadline, max_deadline_width)} |"
      end

      next unless verbose

      display_artist = record["display_artist"]
      artist_name = display_artist.is_a?(Hash) ? display_artist["name"] : display_artist
      puts "  アーティスト: #{artist_name}"
      puts "  URL: #{record['url']}"
      puts "  HTTPステータス: #{record['url_status_code']}" if verify && record["url_status_code"]
    end
  end

  # ============================================================
  # URL状態をフォーマット
  # ============================================================
  def format_url_status(record)
    case record["url_status"]
    when "not_found"
      Colors.red("配信終了")
    when "exists"
      Colors.green("存在")
    when "error"
      Colors.yellow("エラー")
    when "no_url"
      Colors.gray("URL無し")
    else
      "-"
    end
  end

  # ============================================================
  # JSON形式出力
  # ============================================================
  def output_json(expired_records, current_time, delete:, verify: false)
    output = {
      current_time: current_time.iso8601,
      current_timestamp: current_time.to_i,
      expired_count: expired_records.size,
      delete_mode: delete,
      verify_mode: verify,
      expired_records: expired_records.map do |record|
        display_artist = record["display_artist"]
        artist_name = display_artist.is_a?(Hash) ? display_artist["name"] : display_artist

        result = {
          objectID: record["objectID"],
          title: record["title"],
          display_artist: artist_name,
          delivery_deadline_date: record["delivery_deadline_date"],
          delivery_deadline_date_i: record["delivery_deadline_date_i"],
          url: record["url"]
        }

        if verify
          result[:url_status] = record["url_status"]
          result[:url_status_code] = record["url_status_code"]
          result[:url_error] = record["url_error"] if record["url_error"]
        end

        result
      end
    }

    # 検証結果サマリーを追加
    if verify
      output[:verification_summary] = {
        not_found: expired_records.count { |r| r["url_status"] == "not_found" },
        exists: expired_records.count { |r| r["url_status"] == "exists" },
        error: expired_records.count { |r| r["url_status"] == "error" },
        no_url: expired_records.count { |r| r["url_status"] == "no_url" }
      }
    end

    puts JSON.pretty_generate(output)
  end

  # ============================================================
  # 配信期限切れレコードの削除
  # ============================================================
  def delete_expired_records(client, records)
    puts ""
    puts Colors.bold("削除対象: #{records.size}件")

    print "本当に削除しますか？ (yes/no): "
    answer = $stdin.gets&.chomp

    unless answer == "yes"
      puts Colors.yellow("削除をキャンセルしました。")
      return
    end

    puts ""
    object_ids = records.pluck("objectID")

    print "削除中... "
    begin
      client.delete_objects(ALGOLIA_INDEX_NAME, object_ids)
      puts "#{records.size}/#{records.size} 完了"
      puts Colors.green("削除成功: #{records.size}件")
    rescue StandardError => e
      puts Colors.red("削除失敗")
      warn "エラー: #{e.message}"
      exit 1
    end
  end

  # ============================================================
  # ヘルパーメソッド
  # ============================================================

  # 配信期限日をフォーマット
  def format_deadline(deadline)
    return "-" if deadline.nil?

    if deadline.is_a?(String) && deadline.match?(/\A\d{4}-\d{2}-\d{2}/)
      Date.parse(deadline).strftime("%Y/%m/%d")
    else
      deadline.to_s
    end
  rescue StandardError
    deadline.to_s
  end

  # タイトルを適切な長さに切り詰め
  def truncate_title(title, max_width: 40)
    return title if display_width(title) <= max_width

    result = ""
    current_width = 0

    title.each_char do |char|
      char_width = char.bytesize > 1 ? 2 : 1
      break if current_width + char_width + 3 > max_width # "..." の分

      result += char
      current_width += char_width
    end

    "#{result}..."
  end

  # 文字列の表示幅を計算（全角=2, 半角=1）
  def display_width(str)
    str.to_s.each_char.sum do |char|
      char.bytesize > 1 ? 2 : 1
    end
  end

  # 表示幅を考慮した左寄せ
  def ljust_display(str, width)
    str.to_s + (" " * [width - display_width(str.to_s), 0].max)
  end
end
# rubocop:enable Metrics/ModuleLength

# ============================================================
# コマンドラインオプション解析とメイン実行
# ============================================================
if __FILE__ == $PROGRAM_NAME || defined?(Rails::Console)
  options = {
    delete: false,
    verify: false,
    verbose: false,
    json: false,
    color: true
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: bin/rails runner lib/check_expired_joysound_utasuki.rb [OPTIONS]"

    opts.on("--delete", "実際に削除を実行（デフォルトは表示のみ）") do
      options[:delete] = true
    end

    opts.on("--verify", "URLにアクセスして配信終了を確認") do
      options[:verify] = true
    end

    opts.on("--verbose", "詳細表示") do
      options[:verbose] = true
    end

    opts.on("--json", "JSON形式で出力") do
      options[:json] = true
    end

    opts.on("--no-color", "カラー出力を無効化") do
      options[:color] = false
    end

    opts.on("-h", "--help", "ヘルプを表示") do
      puts opts
      exit
    end
  end.parse!(ARGV)

  CheckExpiredJoysoundUtasuki.run(**options)
end
