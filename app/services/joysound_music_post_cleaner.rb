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
  attr_reader :deleted_count, :checked_count, :errors

  def initialize(progress: nil)
    @progress = progress
    @deleted_count = 0
    @checked_count = 0
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
      errors: @errors
    }
  end

  private

  attr_reader :progress

  def process_record(record)
    if UrlChecker.url_exists?(record.url)
      Rails.logger.info("URL still exists for expired record: #{record.title} by #{record.artist}")
    else
      record.destroy!
      @deleted_count += 1
      Rails.logger.info("Deleted expired JoysoundMusicPost: #{record.title} by #{record.artist}")
    end
  rescue StandardError => e
    error_message = "Failed to process record ID #{record.id}: #{e.message}"
    @errors << error_message
    Rails.logger.error(error_message)
  end

  def report_progress(total_count)
    return unless progress
    return progress.call(percentage: 96, status: "期限切れ確認中", label: "期限切れミュージックポストを確認しています", detail: "処理対象はありません", current: 0, total: 0) if total_count.zero?
    return unless @checked_count == total_count || (@checked_count % 10).zero?

    progress.call(
      percentage: (8 + (88 * (@checked_count.to_f / total_count))).floor.clamp(8, 96),
      status: "期限切れ確認中",
      label: "期限切れミュージックポストを確認しています",
      detail: "処理済み: #{@checked_count}/#{total_count}件",
      current: @checked_count,
      total: total_count
    )
  end
end
