require 'test_helper'

class ParallelProcessorTest < ActiveSupport::TestCase
  class DummyProcessor
    include ParallelProcessor
  end

  # factoryが呼ばれる度に生成数をカウントし、生成したワーカー自身に処理済みレコードとteardown状態を記録させるフェイクワーカー。
  class FakeWorker
    attr_reader :processed_records
    attr_accessor :torn_down

    def initialize
      @processed_records = []
      @torn_down = false
    end
  end

  teardown do
    ENV.delete('SCRAPING_THREAD_COUNT')
    ENV.delete('SCRAPING_CONSECUTIVE_FAILURE_LIMIT')
  end

  test '既定（スレッド数1）では各要素を順序通りに1回ずつ処理し、進捗の最終currentが要素数と一致する' do
    records = [1, 2, 3, 4, 5]
    processed = []
    progress_calls = []
    progress = ->(**attrs) { progress_calls << attrs }

    DummyProcessor.process_with_progress(records, progress:) do |record|
      processed << record
    end

    assert_equal records, processed
    assert_equal records.size, progress_calls.last[:current]
    assert_equal records.size, progress_calls.last[:total]
  end

  test 'SCRAPING_THREAD_COUNT>1では各要素がちょうど1回ずつ処理され、進捗の最終currentが要素数と一致する' do
    ENV['SCRAPING_THREAD_COUNT'] = '3'
    records = (1..20).to_a
    mutex = Mutex.new
    processed = []
    progress_calls = []
    progress = ->(**attrs) { mutex.synchronize { progress_calls << attrs } }

    DummyProcessor.process_with_progress(records, progress:) do |record|
      mutex.synchronize { processed << record }
    end

    assert_equal records.sort, processed.sort
    assert_equal records.size, processed.size
    assert_equal records.size, progress_calls.last[:current]
    assert_equal records.size, progress_calls.last[:total]
  end

  test 'total_countが0のときは早期returnし、reporter.startがtotal:0で呼ばれる' do
    progress_calls = []
    progress = ->(**attrs) { progress_calls << attrs }

    DummyProcessor.process_with_progress([], progress:) { |_record| flunk 'yieldされてはならない' }

    assert_equal 1, progress_calls.size
    assert_equal 0, progress_calls.first[:current]
    assert_equal 0, progress_calls.first[:total]
  end

  test 'ActiveRecord::Relationでも既定（スレッド数1）で各レコードを1回ずつ処理する' do
    artists = Array.new(3) { create_display_artist }
    relation = DisplayArtist.where(id: artists.map(&:id))
    processed = []
    progress_calls = []
    progress = ->(**attrs) { progress_calls << attrs }

    DummyProcessor.process_with_progress(relation, progress:) do |record|
      processed << record
    end

    assert_equal artists.sort_by(&:id), processed.sort_by(&:id)
    assert_equal artists.size, progress_calls.last[:current]
    assert_equal artists.size, progress_calls.last[:total]
  end

  test 'ActiveRecord::RelationでもSCRAPING_THREAD_COUNT>1で各レコードがちょうど1回ずつ処理される' do
    ENV['SCRAPING_THREAD_COUNT'] = '3'
    artists = Array.new(10) { create_display_artist }
    relation = DisplayArtist.where(id: artists.map(&:id))
    mutex = Mutex.new
    processed = []

    DummyProcessor.process_with_progress(relation, progress: ->(**_attrs) {}) do |record|
      mutex.synchronize { processed << record }
    end

    assert_equal artists.map(&:id).sort, processed.map(&:id).sort
    assert_equal artists.size, processed.size
  end

  test 'ActiveRecord::Relationはeach_sliceではなくfind_in_batches経由でバッチ処理される（メモリ境界化）' do
    ENV['SCRAPING_THREAD_COUNT'] = '3'
    artists = Array.new(5) { create_display_artist }
    relation = DisplayArtist.where(id: artists.map(&:id))
    processed = []
    mutex = Mutex.new

    # Array向けのeach_sliceパス（全件を配列化する経路）が使われていないことを確認する。
    # find_in_batchesはSQLのLIMIT/OFFSET相当でバッチを取得するため、全件を一括メモリ展開しない。
    relation.define_singleton_method(:each_slice) do |*_args|
      raise 'each_sliceが呼ばれてはならない（ActiveRecord::Relationはfind_in_batches経由であるべき）'
    end

    DummyProcessor.process_with_progress(relation, progress: ->(**_attrs) {}) do |record|
      mutex.synchronize { processed << record }
    end

    assert_equal artists.map(&:id).sort, processed.map(&:id).sort
  end

  test 'worker_factory指定時、逐次実行ではfactoryは1回だけ呼ばれ、全レコードが同一workerで処理され、shutdown後にteardownされる' do
    records = [1, 2, 3, 4, 5]
    factory_call_count = 0
    torn_down_workers = []

    DummyProcessor.process_with_progress(
      records,
      progress: ->(**_attrs) {},
      worker_factory: lambda {
        factory_call_count += 1
        FakeWorker.new
      },
      worker_teardown: lambda { |worker|
        worker.torn_down = true
        torn_down_workers << worker
      }
    ) do |record, worker|
      worker.processed_records << record
    end

    assert_equal 1, factory_call_count
    assert_equal 1, torn_down_workers.size
    assert_equal records, torn_down_workers.first.processed_records
    assert torn_down_workers.first.torn_down
  end

  test 'worker_factory指定時、並列実行ではfactory呼び出し数がthread_count以下で、各レコードがちょうど1回処理され、生成された全workerがteardownされる' do
    ENV['SCRAPING_THREAD_COUNT'] = '3'
    records = (1..20).to_a
    mutex = Mutex.new
    created_workers = []
    processed = []

    DummyProcessor.process_with_progress(
      records,
      progress: ->(**_attrs) {},
      worker_factory: lambda {
        mutex.synchronize do
          worker = FakeWorker.new
          created_workers << worker
          worker
        end
      },
      worker_teardown: ->(worker) { worker.torn_down = true }
    ) do |record, worker|
      mutex.synchronize { processed << record }
      worker.processed_records << record
    end

    assert_equal records.sort, processed.sort
    assert_operator created_workers.size, :<=, 3
    assert created_workers.all?(&:torn_down)
  end

  test 'worker_teardownが例外を投げても他のworkerのteardownは実行され、例外は伝播しない' do
    records = [1, 2]
    teardown_calls = []

    DummyProcessor.process_with_progress(
      records,
      progress: ->(**_attrs) {},
      worker_factory: -> { FakeWorker.new },
      worker_teardown: lambda { |worker|
        teardown_calls << worker
        raise 'teardown boom'
      }
    ) do |record, worker|
      worker.processed_records << record
    end

    assert_equal 1, teardown_calls.size
  end

  test 'continue_on_error: false（既定）ではブロックが例外を投げると従来通り伝播する' do
    error = assert_raises(RuntimeError) do
      DummyProcessor.process_with_progress([1, 2, 3], progress: ->(**_attrs) {}) do |record|
        raise 'boom' if record == 2
      end
    end

    assert_equal 'boom', error.message
  end

  test 'continue_on_error: trueでは一部レコードが例外を投げても全レコードが処理試行され、例外は伝播せず失敗が集約される（逐次）' do
    records = [1, 2, 3, 4, 5]
    processed = []

    result = DummyProcessor.process_with_progress(records, progress: ->(**_attrs) {}, continue_on_error: true) do |record|
      raise "boom #{record}" if [2, 4].include?(record)

      processed << record
    end

    assert_equal [1, 3, 5], processed
    assert_equal 2, result[:failed_count]
    assert_equal 2, result[:failures].size
    assert_not result[:stopped]
  end

  test 'continue_on_error: trueでは一部レコードが例外を投げても全レコードが処理試行され、例外は伝播せず失敗が集約される（並列）' do
    ENV['SCRAPING_THREAD_COUNT'] = '3'
    records = (1..20).to_a
    mutex = Mutex.new
    processed = []

    result = DummyProcessor.process_with_progress(records, progress: ->(**_attrs) {}, continue_on_error: true) do |record|
      raise "boom #{record}" if (record % 5).zero?

      mutex.synchronize { processed << record }
    end

    assert_equal 16, processed.size
    assert_equal 4, result[:failed_count]
    assert_not result[:stopped]
  end

  test '連続失敗が閾値に達すると早期終了し、以降のレコードは処理されない（逐次）' do
    ENV['SCRAPING_CONSECUTIVE_FAILURE_LIMIT'] = '3'
    records = (1..10).to_a
    processed = []

    result = DummyProcessor.process_with_progress(records, progress: ->(**_attrs) {}, continue_on_error: true) do |record|
      processed << record
      raise "boom #{record}"
    end

    assert_equal [1, 2, 3], processed
    assert_equal 3, result[:failed_count]
    assert result[:stopped]
  end

  test '並列実行でも連続失敗が閾値に達するとstoppedが立つ（非決定的なため停止したことのみ確認する）' do
    ENV['SCRAPING_THREAD_COUNT'] = '2'
    ENV['SCRAPING_CONSECUTIVE_FAILURE_LIMIT'] = '2'
    records = (1..20).to_a

    result = DummyProcessor.process_with_progress(records, progress: ->(**_attrs) {}, continue_on_error: true) do |_record|
      raise 'boom'
    end

    assert result[:stopped]
    assert_operator result[:failed_count], :<=, records.size
  end

  test '成功が挟まると連続失敗カウンタがリセットされ、閾値に達しても早期終了しない' do
    ENV['SCRAPING_CONSECUTIVE_FAILURE_LIMIT'] = '2'
    records = (1..6).to_a
    processed = []

    result = DummyProcessor.process_with_progress(records, progress: ->(**_attrs) {}, continue_on_error: true) do |record|
      processed << record
      raise "boom #{record}" if record.odd?
    end

    assert_equal records, processed
    assert_equal 3, result[:failed_count]
    assert_not result[:stopped]
  end
end
