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
  end
end
