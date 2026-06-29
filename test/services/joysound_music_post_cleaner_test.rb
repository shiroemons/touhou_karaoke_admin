require 'test_helper'

class JoysoundMusicPostCleanerTest < ActiveSupport::TestCase
  test 'dry run reports expired missing posts without deleting them' do
    post = JoysoundMusicPost.create!(
      title: 'Expired Preview',
      artist: 'ZUN',
      producer: 'producer',
      delivery_deadline_on: Date.yesterday,
      url: 'https://example.com/music-post/expired-preview'
    )

    with_stubbed_class_method(UrlChecker, :url_exists?, ->(_url) { false }) do
      result = nil
      assert_no_difference -> { JoysoundMusicPost.count } do
        result = JoysoundMusicPostCleaner.new(dry_run: true).cleanup_expired_records
      end

      assert_equal 1, result.fetch(:checked)
      assert_equal 1, result.fetch(:deleted)
      assert_equal post.id, result.fetch(:deleted_records).first.fetch(:id)
      assert JoysoundMusicPost.exists?(post.id)
    end
  end

  test 'delete mode removes expired missing posts' do
    post = JoysoundMusicPost.create!(
      title: 'Expired Delete',
      artist: 'ZUN',
      producer: 'producer',
      delivery_deadline_on: Date.yesterday,
      url: 'https://example.com/music-post/expired-delete'
    )

    with_stubbed_class_method(UrlChecker, :url_exists?, ->(_url) { false }) do
      result = nil
      assert_difference -> { JoysoundMusicPost.count }, -1 do
        result = JoysoundMusicPostCleaner.new(dry_run: false).cleanup_expired_records
      end

      assert_equal 1, result.fetch(:deleted)
      assert_equal post.id, result.fetch(:deleted_records).first.fetch(:id)
      assert_not JoysoundMusicPost.exists?(post.id)
    end
  end

  test 'reports progress through Admin::ProgressReporter' do
    JoysoundMusicPost.create!(
      title: 'Expired Progress',
      artist: 'ZUN',
      producer: 'producer',
      delivery_deadline_on: Date.yesterday,
      url: 'https://example.com/music-post/expired-progress'
    )
    progress_payloads = []

    with_stubbed_class_method(UrlChecker, :url_exists?, ->(_url) { true }) do
      JoysoundMusicPostCleaner.new(progress: ->(**payload) { progress_payloads << payload }).cleanup_expired_records
    end

    assert_equal 2, progress_payloads.size
    assert_equal({ percentage: 8, status: '期限切れ確認中', label: '期限切れミュージックポストを確認しています', detail: '処理済み: 0/1件', current: 0, total: 1 }, progress_payloads.first)
    assert_equal({ percentage: 96, status: '期限切れ確認中', label: '期限切れミュージックポストを確認しています', detail: '処理済み: 1/1件', current: 1, total: 1 }, progress_payloads.second)
  end

  private

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
