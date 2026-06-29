# frozen_string_literal: true

class JoysoundMusicPostDeadlineSyncer
  def initialize(progress: nil, error_reporter: ErrorReportService.new)
    @progress = progress
    @error_reporter = error_reporter
    @errors = []
    @updated_count = 0
  end

  def call
    songs_with_utasuki = Song.music_post
                             .joins(:song_with_joysound_utasuki)
                             .includes(:song_with_joysound_utasuki)
    deadline_lookup = JoysoundMusicPost.pluck(:url, :delivery_deadline_on).to_h
    total_count = songs_with_utasuki.count

    Rails.logger.info("Starting optimized delivery deadline update: #{total_count} songs")

    songs_with_utasuki.find_each.with_index(1) do |song, index|
      log_progress(song, index, total_count)
      report_progress(index - 1, total_count)
      sync_song_deadline(song, deadline_lookup)
      report_progress(index, total_count)
    end

    Rails.logger.info("Delivery deadline update completed: #{@updated_count} updated")
    {
      total_processed: total_count,
      updated: @updated_count,
      errors: @errors
    }
  end

  private

  attr_reader :progress, :error_reporter

  def sync_song_deadline(song, deadline_lookup)
    utasuki_record = song.song_with_joysound_utasuki
    new_deadline = deadline_lookup[utasuki_record.url]
    return unless new_deadline && utasuki_record.delivery_deadline_date != new_deadline

    utasuki_record.update!(delivery_deadline_date: new_deadline)
    @updated_count += 1
    Rails.logger.debug { "Updated delivery deadline for: #{song.title}" }
  rescue StandardError => e
    error_message = "Error updating song #{song.id}: #{e.message}"
    @errors << error_message
    error_reporter.add_error(type: :deadline_update, message: error_message, record: song, exception: e)
    Rails.logger.error(error_message)
  end

  def report_progress(current, total)
    return unless progress

    Admin::ProgressReporter.new(
      progress:,
      status: "配信期限更新中",
      label: "ミュージックポスト配信期限を更新しています"
    ).advance(current:, total:, force: true)
  end

  def log_progress(song, index, total)
    progress_percentage = total.to_i.positive? ? (index.to_f / total * 100).round(2) : 100
    Rails.logger.debug { "#{index}/#{total} (#{progress_percentage}%): #{song.title}" }
  end
end
