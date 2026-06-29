# frozen_string_literal: true

# 期限切れのJOYSOUND MusicPostレコードの削除処理を行うサービスクラス
#
# 概要:
#   配信期限が過ぎたJOYSOUNDミュージックポストのレコードを確認し、
#   URLが存在しない場合のみ削除する
#
# 使用例:
#   cleaner = JoysoundMusicPostCleaner.new
#   result = cleaner.cleanup_expired_records
#   # => { checked: 10, deleted: 3, errors: [] }
#
# 処理内容:
#   1. delivery_deadline_onが現在日より前のレコードを取得
#   2. 各レコードのURLをUrlCheckerで確認
#   3. URLが存在しない場合のみレコードを削除
#   4. 処理結果を統計情報として返す
#
# 戻り値:
#   - checked: 確認したレコード数
#   - deleted: 削除したレコード数
#   - errors: エラーメッセージの配列
class JoysoundMusicPostCleaner
  attr_reader :deleted_count, :checked_count, :deleted_records, :errors

  def initialize(dry_run: false, progress: nil)
    @dry_run = dry_run
    @progress = progress
    @deleted_count = 0
    @checked_count = 0
    @deleted_records = []
    @errors = []
  end

  def cleanup_expired_records
    expired_records = JoysoundMusicPost.where(delivery_deadline_on: ...Date.current)
    total_count = expired_records.count

    expired_records.find_each do |record|
      report_progress(total_count)
      @checked_count += 1
      process_record(record)
      report_progress(total_count)
    end

    {
      checked: @checked_count,
      deleted: @deleted_count,
      deleted_records: @deleted_records,
      errors: @errors
    }
  end

  private

  attr_reader :progress

  def process_record(record)
    if UrlChecker.url_exists?(record.url)
      Rails.logger.info("URL still exists for expired record: #{record.title} by #{record.artist}")
    else
      @deleted_records << record_info(record)
      record.destroy! unless @dry_run
      @deleted_count += 1
      action = @dry_run ? 'Would delete' : 'Deleted'
      Rails.logger.info("#{action} expired JoysoundMusicPost: #{record.title} by #{record.artist}")
    end
  rescue StandardError => e
    error_message = "Failed to process record ID #{record.id}: #{e.message}"
    @errors << error_message
    Rails.logger.error(error_message)
  end

  def record_info(record)
    {
      id: record.id,
      title: record.title,
      artist: record.artist,
      producer: record.producer,
      delivery_deadline_on: record.delivery_deadline_on,
      url: record.url,
      joysound_url: record.joysound_url
    }
  end

  def report_progress(total_count)
    return unless progress

    reporter = Admin::ProgressReporter.new(
      progress:,
      status: "期限切れ確認中",
      label: "期限切れミュージックポストを確認しています"
    )
    return reporter.start(total: 0) if total_count.zero?

    reporter.advance(current: @checked_count, total: total_count)
  end
end
