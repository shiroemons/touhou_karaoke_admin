require 'test_helper'

class ParallelProcessorTest < ActiveSupport::TestCase
  class DummyProcessor
    include ParallelProcessor
  end

  teardown do
    ENV.delete('SCRAPING_THREAD_COUNT')
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
end
