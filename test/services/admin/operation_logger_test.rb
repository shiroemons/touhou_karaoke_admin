# frozen_string_literal: true

require 'test_helper'

module Admin
  class OperationLoggerTest < ActiveSupport::TestCase
    test 'formats operation log messages as key value pairs' do
      message = OperationLogger.message(
        event: 'external_fetch',
        action: 'delete',
        resource: 'joysound_music_post',
        attributes: { id: 1, title: '  テスト 曲  ', error: nil }
      )

      assert_equal 'event=external_fetch action=delete resource=joysound_music_post id=1 title=テスト 曲', message
    end

    test 'rejects unsupported log levels' do
      assert_raises(ArgumentError) do
        OperationLogger.log(level: :fatal, event: 'external_fetch', action: 'delete', resource: 'song')
      end
    end
  end
end
