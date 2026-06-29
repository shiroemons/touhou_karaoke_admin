# frozen_string_literal: true

class JoysoundMusicPostUrlRefresher
  def initialize(progress: nil, error_reporter: ErrorReportService.new)
    @progress = progress
    @error_reporter = error_reporter
    @errors = []
    @skipped_count = 0
    @deleted_count = 0
  end

  def call
    music_post_songs = Song.music_post.includes(:song_with_joysound_utasuki)
    total_count = music_post_songs.count

    Rails.logger.info("Starting efficient refresh: #{total_count} songs")

    music_post_songs.find_each.with_index(1) do |song, index|
      log_progress(song, index, total_count)
      report_progress(index - 1, total_count)
      refresh_song(song)
      report_progress(index, total_count)
    end

    Rails.logger.info("Refresh completed: deleted #{@deleted_count}, skipped #{@skipped_count}, errors #{@errors.count}")
    {
      total_checked: total_count,
      deleted: @deleted_count,
      skipped: @skipped_count,
      errors: @errors
    }
  end

  private

  attr_reader :progress, :error_reporter

  def refresh_song(song)
    result = UrlChecker.check_url(song.url)

    if result[:exists] == false && result[:status_code] == 404
      song.destroy!
      @deleted_count += 1
      Rails.logger.info("Deleted unavailable song (404): #{song.title}")
    elsif result[:exists].nil? && result[:should_retry]
      @skipped_count += 1
      Rails.logger.warn("Skipped song due to network error: #{song.title} (#{result[:error]})")
    elsif result[:exists] == true
      Rails.logger.debug { "Song still available: #{song.title}" }
    end
  rescue StandardError => e
    error_message = "Error checking song #{song.id}: #{e.message}"
    @errors << error_message
    error_reporter.add_error(type: :url_check, message: error_message, record: song, exception: e)
    Rails.logger.error(error_message)
  end

  def report_progress(current, total)
    return unless progress

    Admin::ProgressReporter.new(
      progress:,
      status: "ミュージックポスト楽曲検証中",
      label: "ミュージックポスト楽曲URLを検証しています"
    ).advance(current:, total:, force: true)
  end

  def log_progress(song, index, total)
    progress_percentage = total.to_i.positive? ? (index.to_f / total * 100).round(2) : 100
    Rails.logger.debug { "#{index}/#{total} (#{progress_percentage}%): #{song.title}" }
  end
end
