# frozen_string_literal: true

# エラーレポートを生成・管理するサービスクラス
#
# 概要:
#   JOYSOUNDミュージックポスト処理中のエラーを詳細にレポートし、
#   エラーの種類別に集計・分析する機能を提供
#
# 使用例:
#   reporter = ErrorReportService.new
#   reporter.add_error(type: :validation, record: song, message: "タイトルが空です")
#   reporter.add_error(type: :network, url: "https://example.com", message: "タイムアウト")
#
#   report = reporter.generate_report
#   puts report[:summary]
#   puts report[:details]
class ErrorReportService
  attr_reader :errors, :start_time

  def initialize
    @errors = []
    @start_time = Time.current
  end

  # エラーを追加
  def add_error(type:, message:, record: nil, url: nil, exception: nil)
    error_entry = {
      type: type,
      message: message,
      timestamp: Time.current,
      record_type: record&.class&.name,
      record_id: record&.id,
      url: url
    }

    if exception
      error_entry[:exception_class] = exception.class.name
      error_entry[:backtrace] = exception.backtrace&.first(3)
    end

    @errors << error_entry
  end

  # エラーレポートを生成
  def generate_report
    {
      summary: generate_summary,
      details: generate_details,
      recommendations: generate_recommendations
    }
  end

  # サマリーを生成
  def generate_summary
    total_errors = @errors.count
    error_types = @errors.group_by { |e| e[:type] }
                         .transform_values(&:count)

    duration = Time.current - @start_time

    {
      total_errors: total_errors,
      error_types: error_types,
      duration_seconds: duration.round(2),
      errors_per_minute: (total_errors / (duration / 60.0)).round(2)
    }
  end

  # 詳細レポートを生成
  def generate_details
    @errors.group_by { |e| e[:type] }.transform_values do |errors|
      {
        count: errors.count,
        samples: errors.first(5).map do |error|
          {
            message: error[:message],
            record: "#{error[:record_type]}##{error[:record_id]}",
            timestamp: error[:timestamp].strftime("%Y-%m-%d %H:%M:%S")
          }
        end
      }
    end
  end

  # 推奨事項を生成
  def generate_recommendations
    recommendations = []

    error_types = @errors.group_by { |e| e[:type] }

    # ネットワークエラーが多い場合
    network_errors = error_types[:network] || []
    if network_errors.count > 10
      recommendations << {
        type: :network,
        message: "ネットワークエラーが#{network_errors.count}件発生しています。接続を確認するか、リトライ間隔を調整してください。"
      }
    end

    # バリデーションエラーが多い場合
    validation_errors = error_types[:validation] || []
    if validation_errors.count > 5
      recommendations << {
        type: :validation,
        message: "バリデーションエラーが#{validation_errors.count}件発生しています。データの整合性を確認してください。"
      }
    end

    # タイムアウトエラーが多い場合
    timeout_errors = @errors.select { |e| e[:message].include?("Timeout") }
    if timeout_errors.count > 5
      recommendations << {
        type: :timeout,
        message: "タイムアウトが頻発しています。タイムアウト値を増やすか、並列処理数を減らすことを検討してください。"
      }
    end

    recommendations
  end

  # エラーをCSVファイルに出力
  def export_to_csv(filename = nil)
    require 'csv'

    filename ||= "error_report_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"

    CSV.open(filename, 'w') do |csv|
      csv << %w[timestamp type message record_type record_id url exception_class]

      @errors.each do |error|
        csv << [
          error[:timestamp].strftime("%Y-%m-%d %H:%M:%S"),
          error[:type],
          error[:message],
          error[:record_type],
          error[:record_id],
          error[:url],
          error[:exception_class]
        ]
      end
    end

    filename
  end

  # ログ形式で出力
  def to_log
    lines = ["=== Error Report ==="]
    lines << "Start Time: #{@start_time}"
    lines << "Total Errors: #{@errors.count}"
    lines << ""

    summary = generate_summary
    lines << "Error Types:"
    summary[:error_types].each do |type, count|
      lines << "  #{type}: #{count}"
    end

    lines << ""
    lines << "Recent Errors:"
    @errors.last(10).each do |error|
      lines << "  [#{error[:timestamp].strftime('%H:%M:%S')}] #{error[:type]}: #{error[:message]}"
    end

    lines.join("\n")
  end
end
