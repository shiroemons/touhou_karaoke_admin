# frozen_string_literal: true

require 'test_helper'

class SongExternalSyncTest < ActiveSupport::TestCase
  class HaltAfterCapture < StandardError; end

  test 'fetch_joysound_songs wires a persistent JoysoundScraper worker_factory and worker_teardown into process_with_progress' do
    captured = capture_process_with_progress_kwargs(Song) { SongExternalSync.fetch_joysound_songs }

    assert_respond_to captured[:worker_factory], :call
    assert_respond_to captured[:worker_teardown], :call

    worker = captured[:worker_factory].call
    assert_instance_of Scrapers::JoysoundScraper, worker
  end

  test 'fetch_joysound_music_post_song wires a persistent JoysoundScraper worker_factory and worker_teardown into process_with_progress' do
    captured = capture_process_with_progress_kwargs(Song) { SongExternalSync.fetch_joysound_music_post_song }

    assert_respond_to captured[:worker_factory], :call
    assert_respond_to captured[:worker_teardown], :call

    worker = captured[:worker_factory].call
    assert_instance_of Scrapers::JoysoundScraper, worker
  end

  test 'fetch_dam_songs wires a persistent DamScraper worker_factory and worker_teardown into process_with_progress' do
    captured = capture_process_with_progress_kwargs(Song) { SongExternalSync.fetch_dam_songs }

    assert_respond_to captured[:worker_factory], :call
    assert_respond_to captured[:worker_teardown], :call

    worker = captured[:worker_factory].call
    assert_instance_of Scrapers::DamScraper, worker
  end

  test 'update_dam_delivery_models wires a persistent DamScraper worker_factory and worker_teardown into process_with_progress' do
    captured = capture_process_with_progress_kwargs(Song) { SongExternalSync.update_dam_delivery_models }

    assert_respond_to captured[:worker_factory], :call
    assert_respond_to captured[:worker_teardown], :call

    worker = captured[:worker_factory].call
    assert_instance_of Scrapers::DamScraper, worker
  end

  private

  # Song.process_with_progressをスタブし、渡されたkwargsを捕捉した直後に例外で処理を打ち切る。
  # ブロック本体やスクレイピング（実サイトへのアクセス）は一切実行されない。
  def capture_process_with_progress_kwargs(klass, &)
    captured = nil
    original = klass.method(:process_with_progress)

    klass.define_singleton_method(:process_with_progress) do |*_args, **kwargs, &_block|
      captured = kwargs
      raise HaltAfterCapture
    end

    assert_raises(HaltAfterCapture, &)
    captured
  ensure
    klass.define_singleton_method(:process_with_progress) do |*args, **kwargs|
      original.call(*args, **kwargs, &)
    end
  end
end
