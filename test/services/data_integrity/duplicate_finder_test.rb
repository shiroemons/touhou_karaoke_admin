# frozen_string_literal: true

require 'test_helper'

module DataIntegrity
  class DuplicateFinderTest < ActiveSupport::TestCase
    test 'reports duplicates for configured table and columns' do
      duplicate_url = 'https://example.com/music-post/duplicate-report'
      records = [
        {
          id: SecureRandom.uuid,
          artist: 'Duplicate Reporter',
          title: 'Duplicate Reporter Song 1',
          producer: 'producer',
          delivery_deadline_on: 1.month.from_now.to_date,
          url: duplicate_url,
          created_at: Time.current,
          updated_at: Time.current
        },
        {
          id: SecureRandom.uuid,
          artist: 'Duplicate Reporter',
          title: 'Duplicate Reporter Song 2',
          producer: 'producer',
          delivery_deadline_on: 1.month.from_now.to_date,
          url: duplicate_url,
          created_at: Time.current,
          updated_at: Time.current
        }
      ]
      # This test intentionally creates already-corrupt data to verify the audit path.
      # rubocop:disable Rails/SkipsModelValidations
      JoysoundMusicPost.insert_all!(records)
      # rubocop:enable Rails/SkipsModelValidations

      results = DuplicateFinder.new(
        checks: [DuplicateFinder::Check.new(table: 'joysound_music_posts', columns: %w[url])]
      ).call

      assert_equal 1, results.size
      assert_equal 'joysound_music_posts', results.first.table
      assert_equal %w[url], results.first.columns
      assert_equal duplicate_url, results.first.rows.first['url']
      assert_equal 2, results.first.rows.first['duplicate_count']
    end

    test 'omits checks without duplicates' do
      results = DuplicateFinder.new(
        checks: [DuplicateFinder::Check.new(table: 'dam_artist_urls', columns: %w[url])]
      ).call

      assert_empty results
    end
  end
end
