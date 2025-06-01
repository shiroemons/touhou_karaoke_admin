# frozen_string_literal: true

# リトライ処理を共通化するためのconcern
module Retryable
  extend ActiveSupport::Concern

  # リトライ可能なエラーのリスト
  RETRYABLE_ERRORS = [
    Ferrum::TimeoutError,
    Ferrum::PendingConnectionsError,
    Ferrum::StatusError,
    Ferrum::NodeNotFoundError
  ].freeze

  class_methods do
    # リトライ処理を含むブロックを実行
    # @param max_retries [Integer] 最大リトライ回数（デフォルト: 3）
    # @param errors [Array<Class>] リトライ対象のエラークラス
    # @param on_retry [Proc] リトライ時に実行する処理
    def with_retry(max_retries: 3, errors: RETRYABLE_ERRORS, on_retry: nil)
      retry_count = 0
      begin
        yield
      rescue *errors => e
        retry_count += 1
        if retry_count > max_retries
          Rails.logger.error("Max retries (#{max_retries}) exceeded: #{e.message}")
          raise
        end

        Rails.logger.warn("Retry #{retry_count}/#{max_retries} due to #{e.class}: #{e.message}")
        on_retry&.call(e, retry_count)
        retry
      end
    end
  end

  # インスタンスメソッドとしても使えるように
  def with_retry(max_retries: 3, errors: RETRYABLE_ERRORS, on_retry: nil, &)
    self.class.with_retry(max_retries:, errors:, on_retry:, &)
  end
end
