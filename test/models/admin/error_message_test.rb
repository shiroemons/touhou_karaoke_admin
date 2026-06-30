# frozen_string_literal: true

require 'test_helper'

module Admin
  class ErrorMessageTest < ActiveSupport::TestCase
    test 'translates common English request and network errors' do
      assert_equal 'リクエストに失敗しました（HTTP 500）。', ErrorMessage.user_facing('Request failed: 500')
      assert_equal 'タイムアウトしました。しばらくしてから再実行してください。', ErrorMessage.user_facing('execution expired')
      assert_equal 'ネットワーク接続に失敗しました。接続状況を確認してから再実行してください。', ErrorMessage.user_facing('connection failed')
    end

    test 'hides unknown exception text by default' do
      assert_equal ErrorMessage::DEFAULT_MESSAGE, ErrorMessage.user_facing('undefined method foo')
      assert_equal '入力してください。', ErrorMessage.user_facing('入力してください。', preserve_unknown: true)
      assert_equal 'DAMの楽曲URLではありません。', ErrorMessage.user_facing('DAMの楽曲URLではありません。')
    end
  end
end
