# frozen_string_literal: true

# JOYSOUNDミュージックポスト関連の処理を統一的に管理するサービスクラス
#
# 概要:
#   JOYSOUNDミュージックポストに関する各種処理を効率的に実行する統合サービス
#
# 主な機能:
#   1. fetch_songs_with_progress - 楽曲データの取得（エラーハンドリング強化）
#   2. refresh_songs_efficiently - URL確認による楽曲の削除（ブラウザ不使用で高速化）
#   3. update_delivery_deadlines_optimized - 配信期限の一括更新（DB最適化）
#   4. cleanup_expired_records - 期限切れレコードのクリーンアップ
#   5. perform_full_maintenance - 上記全ての処理を統合実行
#
# 改善点:
#   - ParallelProcessorによる並列処理
#   - 詳細な進捗表示とログ出力
#   - 統一的なエラーハンドリング
#   - HTTPリクエストベースのURL確認（ブラウザ不使用）
#   - データベースクエリの最適化（N+1問題の解消）
#
# 使用例:
#   manager = JoysoundMusicPostManager.new
#
#   # 個別実行
#   result = manager.fetch_songs_with_progress
#   result = manager.refresh_songs_efficiently
#   result = manager.update_delivery_deadlines_optimized
#
#   # 統合実行
#   results = manager.perform_full_maintenance
#
# 統計情報:
#   各メソッドは処理結果として以下の情報を含むハッシュを返す:
#   - fetched/updated/deleted: 処理件数
#   - errors: エラーメッセージの配列
#   - その他メソッド固有の情報
class JoysoundMusicPostManager
  include ParallelProcessor

  attr_reader :stats, :error_reporter

  def initialize(process_id: nil)
    @stats = {
      fetched: 0,
      updated: 0,
      deleted: 0,
      errors: [],
      skipped: 0
    }
    @error_reporter = ErrorReportService.new
    @process_id = process_id || "joysound_fetch_#{Time.current.strftime('%Y%m%d_%H%M%S')}"
  end

  # 楽曲の取得処理（改善版）
  def fetch_songs_with_progress(progress: nil)
    scraper = Scrapers::JoysoundScraper.new
    prioritized_posts = JoysoundMusicPostPrioritizer.call

    Rails.logger.info("Starting JOYSOUND music post song fetch: #{prioritized_posts.count} posts")

    process_with_progress(
      prioritized_posts,
      label: "JOYSOUND Music Posts",
      progress:,
      progress_options: { status: "ミュージックポスト楽曲取得中", label: "ミュージックポスト楽曲を取得しています" }
    ) do |record|
      process_music_post_record(scraper, record)
    end

    generate_final_report
    @stats
  rescue StandardError => e
    record_error("Fatal error in fetch process: #{e.message}", type: :fatal, exception: e)
    Admin::OperationLogger.log(level: :error, event: :external_fetch, action: :error, resource: :joysound_music_post, error: e.message)
    generate_final_report
    @stats
  end

  # URL存在確認による楽曲の更新処理（改善版）
  def refresh_songs_efficiently(progress: nil)
    result = JoysoundMusicPostUrlRefresher.new(progress:, error_reporter: @error_reporter).call
    @stats[:deleted] += result[:deleted]
    @stats[:skipped] += result[:skipped]
    @stats[:errors].concat(result[:errors])
    result
  end

  # 配信期限の一括更新処理（改善版）
  def update_delivery_deadlines_optimized(progress: nil)
    result = JoysoundMusicPostDeadlineSyncer.new(progress:, error_reporter: @error_reporter).call
    @stats[:updated] += result[:updated]
    @stats[:errors].concat(result[:errors])
    result
  end

  # 期限切れレコードのクリーンアップ
  def cleanup_expired_records(progress: nil)
    cleaner = JoysoundMusicPostCleaner.new(progress:)
    result = cleaner.cleanup_expired_records

    @stats[:deleted] += result[:deleted]
    result[:errors].each { |error| record_error(error, type: :cleanup) }

    result
  end

  # 統合的なメンテナンス処理
  def perform_full_maintenance(progress: nil)
    JoysoundMusicPostMaintenanceRunner.new(manager: self, progress:).call
  end

  private

  def report_progress(progress, current, total, status:, label:)
    return unless progress
    return unless current == total || (current % 10).zero?

    Admin::ProgressReporter.new(progress:, status:, label:).advance(current:, total:, force: true)
  end

  def process_music_post_record(scraper, record)
    return if record.joysound_url.blank?

    begin
      scraper.scrape_music_post_page(record)
      @stats[:fetched] += 1
    rescue ActiveRecord::RecordInvalid => e
      error_details = if e.record.respond_to?(:errors)
                        e.record.errors.full_messages.join(", ")
                      else
                        e.message
                      end
      error_message = "Error processing record #{record.id}: #{error_details}"
      record_error(
        error_message,
        type: :validation,
        message: error_details,
        record: e.record,
        exception: e
      )
      Admin::OperationLogger.log(
        level: :error,
        event: :external_fetch,
        action: :error,
        resource: :joysound_music_post,
        id: record.id,
        error: error_details,
        record: e.record.inspect,
        validation_errors: (e.record.errors.details if e.record.respond_to?(:errors))
      )
    rescue StandardError => e
      error_message = "Error processing record #{record.id}: #{e.message}"
      record_error(
        error_message,
        type: :general,
        message: e.message,
        record: record,
        exception: e
      )
      Admin::OperationLogger.log(level: :error, event: :external_fetch, action: :error, resource: :joysound_music_post, id: record.id, error: e.message, backtrace: e.backtrace.first(5).join("\n"))
    end
  end

  def record_error(error_message, type:, message: nil, record: nil, exception: nil)
    @stats[:errors] << error_message
    @error_reporter.add_error(type:, message: message || error_message, record:, exception:)
  end

  def generate_final_report
    report = @error_reporter.generate_report

    Rails.logger.info("=== Final Report ===")
    Rails.logger.info("Statistics: #{@stats}")
    Rails.logger.info("Error Summary: #{report[:summary]}")

    if report[:recommendations].any?
      Rails.logger.info("Recommendations:")
      report[:recommendations].each do |rec|
        Rails.logger.info("  - #{rec[:message]}")
      end
    end

    # エラーが多い場合はCSVファイルに出力
    return unless @stats[:errors].count > 20

    csv_file = @error_reporter.export_to_csv(Rails.root.join("tmp/error_reports/#{@process_id}.csv"))
    Rails.logger.info("Error details exported to: #{csv_file}")
  end
end
