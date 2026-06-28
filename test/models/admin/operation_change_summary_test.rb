require 'test_helper'

module Admin
  class OperationChangeSummaryTest < ActiveSupport::TestCase
    test 'summarizes created records by resource label' do
      summary = OperationChangeSummary.new(resources: [ResourceRegistry.fetch(:display_artist)])
      baseline = summary.snapshot
      started_at = 1.second.ago

      create_display_artist

      assert_includes summary.summarize(baseline:, started_at:), 'アーティスト 追加1件'
    end

    test 'returns no changes message when tracked records are unchanged' do
      summary = OperationChangeSummary.new(resources: [ResourceRegistry.fetch(:display_artist)])
      baseline = summary.snapshot

      assert_equal OperationChangeSummary::NO_CHANGES_MESSAGE, summary.summarize(baseline:, started_at: Time.current)
    end
  end
end
