# frozen_string_literal: true

# 大量データの並列処理を共通化するためのconcern
module ParallelProcessor
  extend ActiveSupport::Concern

  # デフォルト設定
  DEFAULT_BATCH_SIZE = 1000
  DEFAULT_PROCESS_COUNT = ENV.fetch('PARALLEL_PROCESS_COUNT', 7).to_i

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
    # @yield [record] 各レコードに対する処理
    def process_with_progress(collection, label: nil, **)
      progress_logger = create_progress_logger(label)

      process_in_parallel(collection, progress_logger:, **) do |record, _index|
        yield(record)
      end
    end

    private

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
