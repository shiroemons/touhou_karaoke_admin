# frozen_string_literal: true

require 'test_helper'

class JoysoundMusicPostManagerTest < ActiveSupport::TestCase
  FakeFailedCleaner = Class.new do
    def cleanup_expired_records
      { deleted: 0, errors: ['cleanup failed'] }
    end
  end

  test 'refresh_songs_efficiently deletes 404 songs and skips retryable network errors' do
    deleted_song = create_music_post_song(title: 'Deleted Music Post Song', url: 'https://example.com/music-post/deleted')
    skipped_song = create_music_post_song(title: 'Skipped Music Post Song', url: 'https://example.com/music-post/skipped')
    kept_song = create_music_post_song(title: 'Kept Music Post Song', url: 'https://example.com/music-post/kept')

    responses = {
      deleted_song.url => { exists: false, status_code: 404 },
      skipped_song.url => { exists: nil, should_retry: true, error: 'timeout' },
      kept_song.url => { exists: true, status_code: 200 }
    }

    result = nil
    with_stubbed_class_method(UrlChecker, :check_url, ->(url) { responses.fetch(url) }) do
      assert_difference -> { Song.count }, -1 do
        result = JoysoundMusicPostManager.new.refresh_songs_efficiently
      end
    end

    assert_equal 3, result.fetch(:total_checked)
    assert_equal 1, result.fetch(:deleted)
    assert_equal 1, result.fetch(:skipped)
    assert_empty result.fetch(:errors)
    assert_not Song.exists?(deleted_song.id)
    assert Song.exists?(skipped_song.id)
    assert Song.exists?(kept_song.id)
  end

  test 'refresh_songs_efficiently records exceptions in stats and error reporter' do
    song = create_music_post_song(title: 'Error Music Post Song', url: 'https://example.com/music-post/error')
    manager = JoysoundMusicPostManager.new

    with_stubbed_class_method(UrlChecker, :check_url, ->(_url) { raise 'connection failed' }) do
      result = manager.refresh_songs_efficiently

      assert_equal 1, result.fetch(:errors).size
      assert_match(/Error checking song #{song.id}: connection failed/, result.fetch(:errors).first)
      assert_equal 1, manager.error_reporter.errors.size
      assert_equal :url_check, manager.error_reporter.errors.first.fetch(:type)
      assert_equal song.id, manager.error_reporter.errors.first.fetch(:record_id)
    end
  end

  test 'update_delivery_deadlines_optimized updates changed deadlines and reports counts' do
    old_deadline = Date.current + 3.days
    new_deadline = Date.current + 10.days
    changed_song = create_music_post_song(title: 'Changed Deadline Song', url: 'https://example.com/music-post/changed')
    unchanged_song = create_music_post_song(title: 'Unchanged Deadline Song', url: 'https://example.com/music-post/unchanged')
    changed_song.song_with_joysound_utasuki.update!(delivery_deadline_date: old_deadline)
    unchanged_song.song_with_joysound_utasuki.update!(delivery_deadline_date: new_deadline)
    JoysoundMusicPost.create!(
      title: 'Changed Deadline Post',
      artist: 'ZUN',
      producer: 'producer',
      delivery_deadline_on: new_deadline,
      url: changed_song.song_with_joysound_utasuki.url
    )
    JoysoundMusicPost.create!(
      title: 'Unchanged Deadline Post',
      artist: 'ZUN',
      producer: 'producer',
      delivery_deadline_on: new_deadline,
      url: unchanged_song.song_with_joysound_utasuki.url
    )

    result = JoysoundMusicPostManager.new.update_delivery_deadlines_optimized

    assert_equal 2, result.fetch(:total_processed)
    assert_equal 1, result.fetch(:updated)
    assert_empty result.fetch(:errors)
    assert_equal new_deadline, changed_song.song_with_joysound_utasuki.reload.delivery_deadline_date
    assert_equal new_deadline, unchanged_song.song_with_joysound_utasuki.reload.delivery_deadline_date
  end

  test 'cleanup_expired_records records cleaner errors in error reporter' do
    manager = JoysoundMusicPostManager.new

    with_stubbed_class_method(JoysoundMusicPostCleaner, :new, ->(**_args) { FakeFailedCleaner.new }) do
      result = manager.cleanup_expired_records

      assert_equal ['cleanup failed'], result.fetch(:errors)
      assert_equal ['cleanup failed'], manager.stats.fetch(:errors)
      assert_equal 1, manager.error_reporter.errors.size
      assert_equal :cleanup, manager.error_reporter.errors.first.fetch(:type)
    end
  end

  private

  def create_music_post_song(title:, url:)
    song = create_song(karaoke_type: 'JOYSOUND(うたスキ)', title:, url:)
    SongWithJoysoundUtasuki.create!(
      song:,
      delivery_deadline_date: Date.current + 1.day,
      url: "#{url}/utasuki"
    )
    song
  end

  def with_stubbed_class_method(klass, method_name, replacement)
    original = klass.method(method_name)
    klass.define_singleton_method(method_name, &replacement)
    yield
  ensure
    klass.define_singleton_method(method_name) do |*args, **kwargs, &block|
      original.call(*args, **kwargs, &block)
    end
  end
end
