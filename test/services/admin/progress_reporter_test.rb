require 'test_helper'

module Admin
  class ProgressReporterTest < ActiveSupport::TestCase
    test 'reports start with zero progress and total' do
      calls = []
      reporter = ProgressReporter.new(progress: ->(**payload) { calls << payload }, status: '処理中', label: '進捗')

      reporter.start(total: 3)

      assert_equal 1, calls.size
      assert_equal 8, calls.first.fetch(:percentage)
      assert_equal '処理済み: 0/3件', calls.first.fetch(:detail)
      assert_equal 0, calls.first.fetch(:current)
      assert_equal 3, calls.first.fetch(:total)
    end

    test 'suppresses intermediate progress unless forced tenth or final' do
      calls = []
      reporter = ProgressReporter.new(progress: ->(**payload) { calls << payload }, status: '処理中', label: '進捗')

      reporter.advance(current: 1, total: 20)
      reporter.advance(current: 10, total: 20)
      reporter.advance(current: 11, total: 20, force: true)
      reporter.advance(current: 20, total: 20)

      reported_counts = calls.map { |payload| payload.fetch(:current) }
      reported_percentages = calls.map { |payload| payload.fetch(:percentage) }

      assert_equal [10, 11, 20], reported_counts
      assert_equal [52, 56, 96], reported_percentages
    end

    test 'calculates bounded percentages for empty and custom ranges' do
      assert_equal 96, ProgressReporter.percentage(0, 0)
      assert_equal 8, ProgressReporter.percentage(0, 10)
      assert_equal 50, ProgressReporter.percentage(5, 10, range: 10..90)
      assert_equal 90, ProgressReporter.percentage(20, 10, range: 10..90)
    end
  end
end
