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
  def fetch_songs_with_progress(resumable: false)
    scraper = Scrapers::JoysoundScraper.new
    prioritized_posts = prioritized_joysound_music_posts

    Rails.logger.info("Starting JOYSOUND music post song fetch: #{prioritized_posts.count} posts")

    if resumable
      processor = ResumableProcessor.new(@process_id)
      processor.process(prioritized_posts) do |record|
        process_music_post_record(scraper, record)
      end
      Rails.logger.info("Progress: #{processor.progress}")
    else
      # ParallelProcessorを使用してバッチ処理
      process_with_progress(prioritized_posts, label: "JOYSOUND Music Posts") do |record|
        process_music_post_record(scraper, record)
      end
    end

    generate_final_report
    @stats
  rescue StandardError => e
    @stats[:errors] << "Fatal error in fetch process: #{e.message}"
    @error_reporter.add_error(type: :fatal, message: e.message, exception: e)
    Rails.logger.error("JoysoundMusicPostManager fetch error: #{e}")
    generate_final_report
    @stats
  end

  # URL存在確認による楽曲の更新処理（改善版）
  def refresh_songs_efficiently
    music_post_songs = Song.music_post.includes(:song_with_joysound_utasuki)
    total_count = music_post_songs.count
    deleted_count = 0
    error_count = 0

    Rails.logger.info("Starting efficient refresh: #{total_count} songs")

    music_post_songs.find_each.with_index(1) do |song, index|
      progress_percentage = (index.to_f / total_count * 100).round(2)
      Rails.logger.debug { "#{index}/#{total_count} (#{progress_percentage}%): #{song.title}" }

      begin
        result = UrlChecker.check_url(song.url)
        
        if result[:exists] == false && result[:status_code] == 404
          # 明確に404の場合のみ削除
          song.destroy!
          deleted_count += 1
          @stats[:deleted] += 1
          Rails.logger.info("Deleted unavailable song (404): #{song.title}")
        elsif result[:exists].nil? && result[:should_retry]
          # ネットワークエラーの場合はスキップ
          @stats[:skipped] += 1
          Rails.logger.warn("Skipped song due to network error: #{song.title} (#{result[:error]})")
        elsif result[:exists] == true
          Rails.logger.debug { "Song still available: #{song.title}" }
        end
      rescue StandardError => e
        error_count += 1
        error_message = "Error checking song #{song.id}: #{e.message}"
        @stats[:errors] << error_message
        Rails.logger.error(error_message)
      end
    end

    Rails.logger.info("Refresh completed: deleted #{deleted_count}, skipped #{@stats[:skipped]}, errors #{error_count}")
    {
      total_checked: total_count,
      deleted: deleted_count,
      skipped: @stats[:skipped],
      errors: @stats[:errors]
    }
  end

  # 配信期限の一括更新処理（改善版）
  def update_delivery_deadlines_optimized
    # バッチでデータを取得して効率化
    songs_with_utasuki = Song.music_post
                             .joins(:song_with_joysound_utasuki)
                             .includes(:song_with_joysound_utasuki)

    # JoysoundMusicPostをハッシュで事前読み込み
    jmp_lookup = JoysoundMusicPost.pluck(:url, :delivery_deadline_on).to_h

    total_count = songs_with_utasuki.count
    updated_count = 0

    Rails.logger.info("Starting optimized delivery deadline update: #{total_count} songs")

    songs_with_utasuki.find_each.with_index(1) do |song, index|
      progress_percentage = (index.to_f / total_count * 100).round(2)
      Rails.logger.debug { "#{index}/#{total_count} (#{progress_percentage}%): #{song.title}" }

      utasuki_record = song.song_with_joysound_utasuki
      new_deadline = jmp_lookup[utasuki_record.url]

      if new_deadline && utasuki_record.delivery_deadline_date != new_deadline
        utasuki_record.update!(delivery_deadline_date: new_deadline)
        updated_count += 1
        @stats[:updated] += 1
        Rails.logger.debug { "Updated delivery deadline for: #{song.title}" }
      end
    rescue StandardError => e
      error_message = "Error updating song #{song.id}: #{e.message}"
      @stats[:errors] << error_message
      Rails.logger.error(error_message)
    end

    Rails.logger.info("Delivery deadline update completed: #{updated_count} updated")
    {
      total_processed: total_count,
      updated: updated_count,
      errors: @stats[:errors]
    }
  end

  # 期限切れレコードのクリーンアップ
  def cleanup_expired_records
    cleaner = JoysoundMusicPostCleaner.new
    result = cleaner.cleanup_expired_records

    @stats[:deleted] += result[:deleted]
    @stats[:errors].concat(result[:errors])

    result
  end

  # 統合的なメンテナンス処理
  def perform_full_maintenance
    Rails.logger.info("Starting full JOYSOUND music post maintenance")

    results = {
      cleanup: cleanup_expired_records,
      fetch: fetch_songs_with_progress,
      refresh: refresh_songs_efficiently,
      update_deadlines: update_delivery_deadlines_optimized
    }

    Rails.logger.info("Full maintenance completed")
    results
  end

  private

  def prioritized_joysound_music_posts
    # 差分URLの取得
    unmatched_urls = JoysoundMusicPost.pluck(:joysound_url) - Song.music_post.pluck(:url)
    unmatched_posts = JoysoundMusicPost.where(joysound_url: unmatched_urls)

    # 1ヶ月以内の配信期限のポスト
    upcoming_posts = JoysoundMusicPost
                     .where(delivery_deadline_on: ...1.month.from_now)
                     .order(delivery_deadline_on: :asc)

    # 優先度順に結合（差分を優先）
    (unmatched_posts.to_a + upcoming_posts.to_a).uniq
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
      @stats[:errors] << error_message
      @error_reporter.add_error(
        type: :validation,
        message: error_details,
        record: e.record,
        exception: e
      )
      Rails.logger.error(error_message)
      Rails.logger.error("Invalid record: #{e.record.inspect}")
      Rails.logger.error("Errors: #{e.record.errors.details}") if e.record.respond_to?(:errors)
    rescue StandardError => e
      error_message = "Error processing record #{record.id}: #{e.message}"
      @stats[:errors] << error_message
      @error_reporter.add_error(
        type: :general,
        message: e.message,
        record: record,
        exception: e
      )
      Rails.logger.error(error_message)
      Rails.logger.error(e.backtrace.first(5).join("\n"))
    end
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
    if @stats[:errors].count > 20
      csv_file = @error_reporter.export_to_csv(Rails.root.join("tmp/error_reports/#{@process_id}.csv"))
      Rails.logger.info("Error details exported to: #{csv_file}")
    end
  end
end
