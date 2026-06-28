require 'test_helper'

class DisplayArtistUrlValidatorTest < ActiveSupport::TestCase
  test 'dry run reports deletable invalid artists without deleting them' do
    artist = DisplayArtist.create!(karaoke_type: 'DAM', name: 'Invalid Artist', url: 'https://example.com/invalid-artist')

    with_stubbed_class_method(UrlChecker, :check_url, ->(_url) { { exists: false, should_retry: false } }) do
      result = nil
      assert_no_difference -> { DisplayArtist.count } do
        result = DisplayArtistUrlValidator.new(delete_invalid: true, dry_run: true).validate_all
      end

      assert_equal 1, result.fetch(:invalid)
      assert_equal 1, result.fetch(:deleted)
      assert_equal artist.id, result.fetch(:deleted_records).first.fetch(:id)
      assert DisplayArtist.exists?(artist.id)
    end
  end

  test 'delete mode removes invalid artists without songs' do
    artist = DisplayArtist.create!(karaoke_type: 'DAM', name: 'Deleted Artist', url: 'https://example.com/deleted-artist')

    with_stubbed_class_method(UrlChecker, :check_url, ->(_url) { { exists: false, should_retry: false } }) do
      result = nil
      assert_difference -> { DisplayArtist.count }, -1 do
        result = DisplayArtistUrlValidator.new(delete_invalid: true, dry_run: false).validate_all
      end

      assert_equal 1, result.fetch(:deleted)
      assert_equal artist.id, result.fetch(:deleted_records).first.fetch(:id)
      assert_not DisplayArtist.exists?(artist.id)
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
