# frozen_string_literal: true

# DisplayArtistのURL検証を行うサービスクラス
#
# 概要:
#   DisplayArtistレコードのURLが有効かどうかを確認し、
#   オプションで無効なURLを持つレコードを削除する
#
# 使用例:
#   # URLの検証のみ（削除しない）
#   validator = DisplayArtistUrlValidator.new
#   result = validator.validate_all
#   # => { checked: 10, invalid: 3, deleted: 0, invalid_records: [...], deleted_records: [], errors: [] }
#
#   # URLの検証と無効なレコードの削除
#   validator = DisplayArtistUrlValidator.new(delete_invalid: true)
#   result = validator.validate_all
#   # => { checked: 10, invalid: 3, deleted: 2, invalid_records: [...], deleted_records: [...], errors: [] }
#
# 処理内容:
#   1. URLが空でないDisplayArtistレコードを取得
#   2. 各レコードのURLをUrlCheckerで確認
#   3. URLが無効な場合、情報を収集
#   4. delete_invalidがtrueの場合、関連するsongsが空のレコードのみ削除
#   5. 処理結果を統計情報として返す
#
# 戻り値:
#   - checked: 確認したレコード数
#   - invalid: 無効なURLを持つレコード数
#   - deleted: 削除したレコード数
#   - invalid_records: 無効なレコードの情報配列 [{ id:, name:, karaoke_type:, url: }, ...]
#   - deleted_records: 削除されたレコードの情報配列 [{ id:, name:, karaoke_type:, url: }, ...]
#   - errors: エラーメッセージの配列
class DisplayArtistUrlValidator
  attr_reader :checked_count, :invalid_count, :deleted_count, :invalid_records, :deleted_records, :errors

  def initialize(delete_invalid: false)
    @delete_invalid = delete_invalid
    @checked_count = 0
    @invalid_count = 0
    @deleted_count = 0
    @invalid_records = []
    @deleted_records = []
    @errors = []
  end

  def validate_all
    records_with_urls = DisplayArtist.where.not(url: ['', nil])
    total_count = records_with_urls.count

    Rails.logger.info("DisplayArtistUrlValidator: Starting validation of #{total_count} records")

    records_with_urls.find_each do |record|
      @checked_count += 1
      log_progress(total_count)
      process_record(record)
    end

    Rails.logger.info("DisplayArtistUrlValidator: Completed. Checked: #{@checked_count}, Invalid: #{@invalid_count}, Deleted: #{@deleted_count}")

    {
      checked: @checked_count,
      invalid: @invalid_count,
      deleted: @deleted_count,
      invalid_records: @invalid_records,
      deleted_records: @deleted_records,
      errors: @errors
    }
  end

  private

  def process_record(record)
    result = UrlChecker.check_url(record.url)

    # ネットワークエラーの場合はスキップ（削除を防ぐ）
    if result[:exists].nil? && result[:should_retry]
      Rails.logger.warn("DisplayArtistUrlValidator: Skipping due to network error - ID: #{record.id}, Name: #{record.name}")
      return
    end

    return if result[:exists]

    # URLが無効な場合
    @invalid_count += 1
    record_info = {
      id: record.id,
      name: record.name,
      karaoke_type: record.karaoke_type,
      url: record.url
    }
    @invalid_records << record_info

    Rails.logger.info("DisplayArtistUrlValidator: Invalid URL found - ID: #{record.id}, Name: #{record.name}, URL: #{record.url}")

    delete_record_if_applicable(record)
  rescue StandardError => e
    error_message = "Failed to process DisplayArtist ID #{record.id}: #{e.message}"
    @errors << error_message
    Rails.logger.error("DisplayArtistUrlValidator: #{error_message}")
  end

  def delete_record_if_applicable(record)
    return unless @delete_invalid

    if record.songs.empty?
      deleted_record_info = {
        id: record.id,
        name: record.name,
        karaoke_type: record.karaoke_type,
        url: record.url
      }
      record.destroy!
      @deleted_count += 1
      @deleted_records << deleted_record_info
      Rails.logger.info("DisplayArtistUrlValidator: Deleted DisplayArtist - ID: #{record.id}, Name: #{record.name}")
    else
      Rails.logger.info("DisplayArtistUrlValidator: Skipping deletion (has #{record.songs.count} songs) - ID: #{record.id}, Name: #{record.name}")
    end
  end

  def log_progress(total_count)
    return unless (@checked_count % 100).zero? || @checked_count == total_count

    percentage = ((Float(@checked_count) / total_count) * 100).floor
    Rails.logger.info("DisplayArtistUrlValidator: Progress #{@checked_count}/#{total_count} (#{percentage}%)")
  end
end
