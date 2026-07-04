# frozen_string_literal: true

module ParallelProcessor
  # スレッド毎の専用ワーカー（例: 専用ブラウザを持つスクレイパ）を生成・追跡し、
  # 処理完了後にまとめて後始末するためのプール。
  #
  # スレッドローカルのキーはプールのインスタンス毎にユニークにしている。こうしないと、
  # 逐次実行（メインスレッドのみで動く）で生成したワーカーが、次回のプール生成後も
  # メインスレッドのスレッドローカル領域に残ってしまい、誤って再利用されてしまう。
  class WorkerPool
    # @param factory [Proc, nil] ワーカーを生成するProc（例: -> { Scraper.new }）。nilならワーカーを使わない。
    # @param teardown [Proc, nil] ワーカーを後始末するProc（例: ->(worker) { worker.browser.quit }）。
    def initialize(factory, teardown)
      @factory = factory
      @teardown = teardown
      @workers = []
      @mutex = Mutex.new
      @thread_local_key = "parallel_worker_pool_#{object_id}"
    end

    # 現在のスレッド用のワーカーを返す。同一スレッドからの呼び出しでは同じワーカーを再利用する。
    # factory未指定ならnilを返す（ワーカーを使わない後方互換のパス）。
    def worker_for_current_thread
      return nil unless @factory

      Thread.current[@thread_local_key] ||= build_and_track_worker
    end

    # 追跡している全ワーカーを後始末する。個々のteardownが例外を投げても、
    # 残りのワーカーの後始末は継続する。teardown未指定なら何もしない。
    def shutdown
      workers = @mutex.synchronize { @workers.dup }
      workers.each { |worker| teardown_worker(worker) } if @teardown
    ensure
      @mutex.synchronize { @workers.clear }
      Thread.current[@thread_local_key] = nil
    end

    private

    def build_and_track_worker
      worker = @factory.call
      @mutex.synchronize { @workers << worker }
      worker
    end

    def teardown_worker(worker)
      @teardown.call(worker)
    rescue StandardError => e
      Rails.logger.warn("ParallelProcessor::WorkerPool: ワーカーの後始末に失敗しました: #{e.message}")
    end
  end
end
