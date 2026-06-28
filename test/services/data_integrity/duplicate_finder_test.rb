# frozen_string_literal: true

require 'test_helper'

module DataIntegrity
  class DuplicateFinderTest < ActiveSupport::TestCase
    test 'reports duplicates for configured table and columns' do
      duplicate_url = 'https://example.com/dam/artists/duplicate-report'
      records = [
        { id: SecureRandom.uuid, url: duplicate_url, created_at: Time.current, updated_at: Time.current },
        { id: SecureRandom.uuid, url: duplicate_url, created_at: Time.current, updated_at: Time.current }
      ]
      # This test intentionally creates already-corrupt data to verify the audit path.
      # rubocop:disable Rails/SkipsModelValidations
      DamArtistUrl.insert_all!(records)
      # rubocop:enable Rails/SkipsModelValidations

      results = DuplicateFinder.new(
        checks: [DuplicateFinder::Check.new(table: 'dam_artist_urls', columns: %w[url])]
      ).call

      assert_equal 1, results.size
      assert_equal 'dam_artist_urls', results.first.table
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
