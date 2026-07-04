# frozen_string_literal: true

module ParallelProcessor
  # continue_on_error: true 時に、レコード単位の失敗を集約し、
  # 連続失敗数が閾値に達したら安全に処理を打ち切るためのトラッカー。
  #
  # 複数スレッドから同時に呼ばれるため、状態変更は全てMutexで保護する。
  class FailureTracker
    # @param limit [Integer] 連続失敗がこの件数に達すると打ち切りを決定する
    def initialize(limit:)
      @limit = limit
      @mutex = Mutex.new
      @failures = []
      @consecutive_failures = 0
      @stopped = false
    end

    # 既に打ち切りが決定しているか
    def stopped?
      @mutex.synchronize { @stopped }
    end

    # 成功を記録し、連続失敗カウンタをリセットする
    def record_success
      @mutex.synchronize { @consecutive_failures = 0 }
    end

    # 失敗を記録する。この呼び出しで連続失敗数が閾値に達し、新たに打ち切りが決定した場合はtrueを返す。
    def record_failure(identifier, error)
      @mutex.synchronize do
        @failures << { record: identifier, error: error.message }
        @consecutive_failures += 1
        next false if @stopped || @consecutive_failures < @limit

        @stopped = true
      end
    end

    # 集約結果のサマリを返す
    def summary
      @mutex.synchronize { { failed_count: @failures.size, failures: @failures.dup, stopped: @stopped } }
    end
  end
end
