# frozen_string_literal: true

# 大量データの並列処理を共通化するためのconcern
module ParallelProcessor
  extend ActiveSupport::Concern

  # デフォルト設定
  DEFAULT_BATCH_SIZE = 1000
  DEFAULT_PROCESS_COUNT = ENV.fetch('PARALLEL_PROCESS_COUNT', 7).to_i
  # サーバー進捗表示付き処理（process_with_server_progress）専用のスレッド数。
  # PARALLEL_PROCESS_COUNT とは独立させ、既定は1（逐次実行）にしている。
  # スクレイパ/ブラウザがまだスレッド安全でないため、既定で並列化されないようにするため。
  DEFAULT_PROGRESS_THREAD_COUNT = 1
  # continue_on_error: true 時、連続でこの件数だけ失敗が続いたら安全のため処理を打ち切る（既定値）。
  DEFAULT_CONSECUTIVE_FAILURE_LIMIT = 10

  class_methods do
    # バッチ処理で並列実行を行う
    # @param collection [Array, ActiveRecord::Relation] 処理対象のコレクション
    # @param batch_size [Integer] バッチサイズ
    # @param process_count [Integer] 並列プロセス数
    # @param progress_logger [Proc] 進捗ログ出力用のProc
    # @yield [record, index] 各レコードに対する処理
    def process_in_parallel(collection, batch_size: DEFAULT_BATCH_SIZE, process_count: DEFAULT_PROCESS_COUNT, progress_logger: nil)
      total_count = collection.is_a?(Array) ? collection.count : collection.size
      current_index = 0

      # IDの配列の場合はバッチでレコードを取得
      if collection.is_a?(Array) && collection.first.is_a?(Integer)
        collection.each_slice(batch_size) do |ids|
          records = yield_records_from_ids(ids)
          process_batch(records, current_index, total_count, process_count, progress_logger) do |record, i|
            yield(record, current_index + i)
          end
          current_index += records.size
        end
      # ActiveRecord::Relationの場合
      elsif collection.respond_to?(:find_in_batches)
        collection.find_in_batches(batch_size:) do |batch|
          process_batch(batch, current_index, total_count, process_count, progress_logger) do |record, i|
            yield(record, current_index + i)
          end
          current_index += batch.size
        end
      # その他のコレクション
      else
        collection.each_slice(batch_size) do |batch|
          process_batch(batch, current_index, total_count, process_count, progress_logger) do |record, i|
            yield(record, current_index + i)
          end
          current_index += batch.size
        end
      end
    end

    # 進捗表示付きの並列処理
    # @param collection [Array, ActiveRecord::Relation] 処理対象のコレクション
    # @param label [String] ログに表示するラベル
    # @param options [Hash] オプション（batch_size, process_count）
    # @param worker_factory [Proc, nil] スレッド毎の専用ワーカーを生成するProc（例: -> { Scraper.new }）
    # @param worker_teardown [Proc, nil] worker_factoryが生成したワーカーを後始末するProc
    # @param continue_on_error [Boolean] trueの場合、1レコードの失敗（例外）を握り潰してログ記録し処理を継続する。
    #   ただし連続失敗が閾値（SCRAPING_CONSECUTIVE_FAILURE_LIMIT）に達すると安全のため打ち切る。
    # @yield [record, worker] 各レコードに対する処理（workerはworker_factory未指定ならnil）
    # @return [Hash, nil] continue_on_error: true の場合は失敗集約情報（failed_count, failures, stopped）。false の場合はnil。
    def process_with_progress(collection, label: nil, progress: nil, progress_options: {}, worker_factory: nil, worker_teardown: nil, continue_on_error: false, **, &)
      return process_with_server_progress(collection, progress:, label:, progress_options:, worker_factory:, worker_teardown:, continue_on_error:, &) if progress

      progress_logger = create_progress_logger(label)

      process_in_parallel(collection, progress_logger:, **) do |record, _index|
        if continue_on_error
          rescue_and_log_failure(record, label:) { yield(record) }
        else
          yield(record)
        end
      end
      nil
    end

    private

    def process_with_server_progress(collection, progress:, label:, progress_options:, worker_factory: nil, worker_teardown: nil, continue_on_error: false, &)
      total_count = collection_total_count(collection)
      reporter = Admin::ProgressReporter.new(
        progress:,
        status: progress_options.fetch(:status, "処理中"),
        label: progress_options.fetch(:label, label || "処理しています")
      )
      reporter.start(total: total_count)
      return if total_count.zero?

      thread_count = progress_thread_count
      processed_count = 0
      mutex = Mutex.new
      advance = lambda do
        mutex.synchronize do
          processed_count += 1
          reporter.advance(current: processed_count, total: total_count)
        end
      end

      failure_tracker = continue_on_error ? ParallelProcessor::FailureTracker.new(limit: consecutive_failure_limit) : nil

      pool = WorkerPool.new(worker_factory, worker_teardown)
      begin
        if thread_count > 1
          process_in_parallel_batches(collection, thread_count:, pool:, advance:, failure_tracker:, label:, &)
        else
          each_collection_record(collection) do |record|
            break if failure_tracker&.stopped?

            guarded_call(record, failure_tracker, label:) { yield(record, pool.worker_for_current_thread) }
            advance.call
          end
        end
      ensure
        pool.shutdown
      end

      failure_tracker&.summary
    end

    # 並列分岐: バッチ単位で読み出し、バッチ内をスレッドで並列処理する。
    # collectionを一括でto_aせず、メモリ使用量をバッチサイズに抑える。
    def process_in_parallel_batches(collection, thread_count:, pool:, advance:, failure_tracker: nil, label: nil)
      each_parallel_batch(collection) do |batch|
        break if failure_tracker&.stopped?

        Parallel.each(batch, in_threads: thread_count) do |record|
          next if failure_tracker&.stopped?

          Rails.application.executor.wrap do
            ActiveRecord::Base.connection_pool.with_connection do
              guarded_call(record, failure_tracker, label:) { yield(record, pool.worker_for_current_thread) }
            end
          end
          advance.call
        end
      end
    end

    # failure_tracker未指定なら素通しでブロックを実行する（continue_on_error: false と同じ挙動）。
    # 指定時は例外を握り潰して失敗を集約し、次のレコードの処理に進めるようにする。
    def guarded_call(record, failure_tracker, label:)
      return yield unless failure_tracker

      begin
        yield
        failure_tracker.record_success
      rescue StandardError => e
        newly_stopped = failure_tracker.record_failure(record_identifier(record), e)
        log_scraping_failure(record, e, label:)
        log_consecutive_failure_stop(label:) if newly_stopped
      end
    end

    # continue_on_error用の軽量版rescue（process_in_parallelのマルチプロセス分岐向け）。
    # プロセスをforkするため状態共有ができず、連続失敗による早期打ち切りはサポートしない。
    def rescue_and_log_failure(record, label:)
      yield
    rescue StandardError => e
      log_scraping_failure(record, e, label:)
    end

    def record_identifier(record)
      record.respond_to?(:id) ? record.id : record.inspect
    end

    # レコード単位の失敗をログ記録する（継続する旨も明示する）。
    # Admin::OperationLogger.log は内部でRails.loggerに書き出すため、二重ログにならないよう
    # 個別のRails.logger呼び出しは行わない（JoysoundMusicPostManagerの既存の使い方に合わせている）。
    def log_scraping_failure(record, error, label:)
      Admin::OperationLogger.log(
        level: :error,
        event: :parallel_processing,
        action: :record_error,
        resource: label || :record,
        id: record_identifier(record),
        error: error.message,
        continued: true
      )
    end

    def log_consecutive_failure_stop(label:)
      Admin::OperationLogger.log(
        level: :error,
        event: :parallel_processing,
        action: :aborted,
        resource: label || :record,
        reason: "連続#{consecutive_failure_limit}件の失敗のため処理を中断しました"
      )
    end

    # SCRAPING_CONSECUTIVE_FAILURE_LIMITで指定された、連続失敗による打ち切り閾値。
    def consecutive_failure_limit
      ENV.fetch('SCRAPING_CONSECUTIVE_FAILURE_LIMIT', DEFAULT_CONSECUTIVE_FAILURE_LIMIT).to_i
    end

    # collectionをバッチ単位（DEFAULT_BATCH_SIZE件ずつ）でyieldする。
    # ActiveRecord::Relationはfind_in_batchesで、それ以外はeach_sliceでバッチ化する。
    def each_parallel_batch(collection, &)
      if collection.respond_to?(:find_in_batches)
        collection.find_in_batches(batch_size: DEFAULT_BATCH_SIZE, &)
      else
        collection.each_slice(DEFAULT_BATCH_SIZE, &)
      end
    end

    # SCRAPING_THREAD_COUNTで指定されたスレッド数を、ActiveRecordのコネクションプールサイズで
    # 上限クランプする（ActiveRecord::ConnectionTimeoutError防止）。最低1は保証する。
    def progress_thread_count
      configured_count = ENV.fetch('SCRAPING_THREAD_COUNT', DEFAULT_PROGRESS_THREAD_COUNT).to_i
      configured_count.clamp(1, ActiveRecord::Base.connection_pool.size)
    end

    def collection_total_count(collection)
      collection.respond_to?(:count) ? collection.count : collection.size
    end

    def each_collection_record(collection, &)
      if collection.respond_to?(:find_each)
        collection.find_each(&)
      else
        collection.each(&)
      end
    end

    # バッチの並列処理
    def process_batch(batch, current_index, total_count, process_count, progress_logger)
      Parallel.each_with_index(batch, in_processes: process_count) do |record, i|
        global_index = current_index + i
        progress_logger&.call(global_index, total_count, record)
        yield(record, i)
      end
    end

    # IDの配列からレコードを取得（オーバーライド可能）
    def yield_records_from_ids(ids)
      where(id: ids)
    end

    # 進捗ログ出力用のProcを作成
    def create_progress_logger(label = nil)
      proc do |index, total, record|
        percentage = ((index + 1) / total.to_f * 100).floor
        message = "#{index + 1}/#{total}: #{percentage}%"
        message += " [Worker: #{Parallel.worker_number}]" if defined?(Parallel.worker_number)
        message += " #{label}" if label
        message += " - #{record.respond_to?(:title) ? record.title : record.inspect}"
        Rails.logger.debug(message)
      end
    end
  end

  # インスタンスメソッドとしても使えるように
  included do
    delegate :process_in_parallel, :process_with_progress, to: :class
  end
end
