# frozen_string_literal: true

module Admin
  class ProgressReporter
    def initialize(progress:, status:, label:, range: 8..96, unit: "件")
      @progress = progress
      @status = status
      @label = label
      @range = range
      @unit = unit
    end

    def start(total:)
      call(current: 0, total:, detail: total.positive? ? "処理済み: 0/#{total}#{unit}" : "処理対象はありません")
    end

    def advance(current:, total:, force: false)
      return unless force || current == total || (current % 10).zero?

      call(current:, total:, detail: "処理済み: #{current}/#{total}#{unit}")
    end

    def self.percentage(current, total, range: 8..96)
      return range.end if total.to_i.zero?

      (range.begin + ((range.end - range.begin) * (current.to_f / total))).floor.clamp(range.begin, range.end)
    end

    private

    attr_reader :progress, :status, :label, :range, :unit

    def call(current:, total:, detail:)
      progress.call(
        percentage: self.class.percentage(current, total, range:),
        status:,
        label:,
        detail:,
        current:,
        total:
      )
    end
  end
end
