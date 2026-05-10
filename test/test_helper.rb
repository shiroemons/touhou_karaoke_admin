ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'securerandom'

module ActiveSupport
  class TestCase
    include ActiveJob::TestHelper

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def assert_policy_permits(policy, *actions)
      actions.each do |action|
        assert policy.public_send(action), "Expected #{policy.class} to permit #{action}"
      end
    end

    def assert_policy_forbids(policy, *actions)
      actions.each do |action|
        assert_not policy.public_send(action), "Expected #{policy.class} to forbid #{action}"
      end
    end

    def assert_scope_resolves_all(scope_class)
      records = [Object.new]
      scope = Object.new
      scope.define_singleton_method(:all) { records }

      assert_same records, scope_class.new(nil, scope).resolve
    end

    def create_original(**attributes)
      defaults = {
        code: "orig-#{SecureRandom.hex(6)}",
        title: '東方テスト作品',
        short_title: '試',
        original_type: 'windows',
        series_order: 99.0
      }
      Original.create!(defaults.merge(attributes))
    end

    def create_original_song(original: create_original, **attributes)
      defaults = {
        code: "song-#{SecureRandom.hex(6)}",
        original:,
        title: 'テスト原曲',
        composer: 'ZUN',
        track_number: 1
      }
      OriginalSong.create!(defaults.merge(attributes))
    end

    def create_display_artist(**attributes)
      defaults = {
        karaoke_type: 'DAM',
        name: "テストアーティスト #{SecureRandom.hex(4)}",
        url: "https://example.com/artists/#{SecureRandom.hex(8)}"
      }
      DisplayArtist.create!(defaults.merge(attributes))
    end

    def create_song(display_artist: create_display_artist, **attributes)
      defaults = {
        display_artist:,
        karaoke_type: display_artist.karaoke_type,
        title: "テスト楽曲 #{SecureRandom.hex(4)}",
        url: "https://example.com/songs/#{SecureRandom.hex(8)}"
      }
      Song.create!(defaults.merge(attributes))
    end

    def create_delivery_model(**attributes)
      defaults = {
        name: "テスト機種 #{SecureRandom.hex(4)}",
        karaoke_type: 'DAM',
        order: (KaraokeDeliveryModel.maximum(:order) || 0) + 1
      }
      KaraokeDeliveryModel.create!(defaults.merge(attributes))
    end
  end
end
