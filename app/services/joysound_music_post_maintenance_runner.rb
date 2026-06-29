# frozen_string_literal: true

class JoysoundMusicPostMaintenanceRunner
  def initialize(manager: JoysoundMusicPostManager.new, progress: nil)
    @manager = manager
    @progress = progress
  end

  def call
    Rails.logger.info("Starting full JOYSOUND music post maintenance")

    results = {
      cleanup: manager.cleanup_expired_records(progress: phase_progress(0...20, "期限切れクリーンアップ")),
      fetch: manager.fetch_songs_with_progress(progress: phase_progress(20...60, "楽曲取得")),
      refresh: manager.refresh_songs_efficiently(progress: phase_progress(60...82, "URL確認")),
      update_deadlines: manager.update_delivery_deadlines_optimized(progress: phase_progress(82..96, "配信期限更新"))
    }

    Rails.logger.info("Full maintenance completed")
    results
  end

  private

  attr_reader :manager, :progress

  def phase_progress(range, phase_label)
    return nil unless progress

    lambda do |**attributes|
      source_percentage = attributes[:percentage].to_i.clamp(0, 100)
      phase_start = range.begin
      phase_end = range.end
      mapped_percentage = phase_start + ((phase_end - phase_start) * (source_percentage / 100.0))
      Admin::ProgressReporter.report(
        progress:,
        **attributes,
        percentage: mapped_percentage.floor.clamp(phase_start, phase_end),
        label: "#{phase_label}: #{attributes[:label]}"
      )
    end
  end
end
