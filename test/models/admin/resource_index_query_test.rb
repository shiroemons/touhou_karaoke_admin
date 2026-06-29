# frozen_string_literal: true

require 'test_helper'

module Admin
  class ResourceIndexQueryTest < ActiveSupport::TestCase
    test 'count association sort uses distinct count and groups by primary key' do
      query = ResourceIndexQuery.new(
        resource: ResourceRegistry.fetch(:circle),
        params: { sort: 'display_artists_count', direction: 'desc' },
        scope: Circle.all,
        per_page_options: [24]
      )

      sql = query.ordered_scope.to_sql

      assert_match(/LEFT OUTER JOIN .*display_artists_circles/i, sql)
      assert_match(/LEFT OUTER JOIN .*display_artists/i, sql)
      assert_match(/GROUP BY .*"circles"."id"/i, sql)
      assert_match(/COUNT\(DISTINCT .*"display_artists"."id"\) DESC/i, sql)
    end

    test 'belongs to association sort joins the association and orders by its display column' do
      query = ResourceIndexQuery.new(
        resource: ResourceRegistry.fetch(:song),
        params: { sort: 'display_artist', direction: 'asc' },
        scope: Song.all,
        per_page_options: [24]
      )

      sql = query.ordered_scope.to_sql

      assert_match(/LEFT OUTER JOIN .*"display_artists"/i, sql)
      assert_match(/ORDER BY .*"display_artists"."name" ASC/i, sql)
    end

    test 'includes combined with association filters does not duplicate records' do
      artist = create_display_artist(name: 'Join Duplicate Artist')
      artist.circles << Circle.create!(name: 'Join Duplicate Circle A')
      artist.circles << Circle.create!(name: 'Join Duplicate Circle B')

      query = ResourceIndexQuery.new(
        resource: ResourceRegistry.fetch(:display_artist),
        params: { filters: { circles: 'present' } },
        scope: DisplayArtist.where(id: artist.id),
        per_page_options: [24]
      )

      assert_equal [artist.id], query.records.map(&:id)
      assert_equal 1, query.total_count
    end

    test 'filtered totals and pagination are calculated from filtered scope' do
      matched = [
        Circle.create!(name: 'Filtered Count Circle A'),
        Circle.create!(name: 'Filtered Count Circle B'),
        Circle.create!(name: 'Filtered Count Circle C')
      ]
      Circle.create!(name: 'Unmatched Count Circle')

      query = ResourceIndexQuery.new(
        resource: ResourceRegistry.fetch(:circle),
        params: { q: 'Filtered Count', page: 2, per_page: 2, view_mode: 'paginated' },
        scope: Circle.order(:name),
        per_page_options: [2, 24]
      )

      assert_equal 3, query.total_count
      assert_equal 2, query.total_pages
      assert_equal 2, query.page
      assert_equal 2, query.per_page
      assert_equal 'paginated', query.view_mode
      assert_equal [matched.third.id], query.records.map(&:id)
    end

    test 'infinite view mode is default and invalid pagination parameters fall back' do
      query = ResourceIndexQuery.new(
        resource: ResourceRegistry.fetch(:circle),
        params: { page: -1, per_page: 999 },
        scope: Circle.all,
        per_page_options: [24, 48]
      )

      assert_equal 1, query.page
      assert_equal 24, query.per_page
      assert_equal 'infinite', query.view_mode
    end
  end
end
