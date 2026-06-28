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
