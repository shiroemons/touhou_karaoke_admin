# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class ResumableProcessorTest < ActiveSupport::TestCase
  Record = Struct.new(:id)

  test 'processes array collections and skips persisted processed ids on resume' do
    Dir.mktmpdir do |dir|
      records = [Record.new('one'), Record.new('two'), Record.new('three')]
      processed = []
      processor = ResumableProcessor.new('array-process', state_dir: dir)

      processor.process(records, batch_size: 2) do |record|
        processed << record.id
        raise 'temporary failure' if record.id == 'two'
      end

      assert_equal %w[one two three], processed
      assert_equal({ total: 3, processed: 2, percentage: 66.67, status: 'completed', errors: 1 }, processor.progress)

      resumed = ResumableProcessor.new('array-process', state_dir: dir)
      resumed_processed = []
      resumed.process(records, batch_size: 2) { |record| resumed_processed << record.id }

      assert_equal ['two'], resumed_processed
      assert_equal({ total: 3, processed: 3, percentage: 100.0, status: 'completed', errors: 1 }, resumed.progress)
    end
  end
end
