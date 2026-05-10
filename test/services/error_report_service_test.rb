require 'test_helper'

class ErrorReportServiceTest < ActiveSupport::TestCase
  test 'collects errors with record url and exception context' do
    service = ErrorReportService.new
    record = create_song
    exception = StandardError.new('Timeout')
    exception.set_backtrace(%w[line1 line2 line3 line4])

    service.add_error(type: :network, message: 'Timeout while fetching', record:, url: record.url, exception:)

    error = service.errors.first
    assert_equal :network, error.fetch(:type)
    assert_equal record.id, error.fetch(:record_id)
    assert_equal record.url, error.fetch(:url)
    assert_equal 'StandardError', error.fetch(:exception_class)
    assert_equal %w[line1 line2 line3], error.fetch(:backtrace)
  end

  test 'generates summary details and recommendations' do
    service = ErrorReportService.new
    11.times { service.add_error(type: :network, message: 'Timeout while fetching') }
    6.times { service.add_error(type: :validation, message: 'invalid') }

    report = service.generate_report

    assert_equal 17, report.dig(:summary, :total_errors)
    assert_equal 11, report.dig(:summary, :error_types, :network)
    assert_equal 6, report.dig(:details, :validation, :count)
    recommendation_types = report.fetch(:recommendations).map { |item| item.fetch(:type) }

    assert_equal %i[network validation timeout], recommendation_types
  end

  test 'exports errors to csv and log text' do
    service = ErrorReportService.new
    service.add_error(type: :validation, message: '入力エラー', url: 'https://example.com')
    path = Rails.root.join('tmp', "error_report_#{SecureRandom.hex(8)}.csv")

    assert_equal path.to_s, service.export_to_csv(path.to_s)
    csv = File.read(path)
    assert_includes csv, 'timestamp,type,message,record_type,record_id,url,exception_class'
    assert_includes csv, '入力エラー'

    log = service.to_log
    assert_includes log, '=== Error Report ==='
    assert_includes log, 'validation: 1'
  ensure
    File.delete(path) if path && File.exist?(path)
  end
end
