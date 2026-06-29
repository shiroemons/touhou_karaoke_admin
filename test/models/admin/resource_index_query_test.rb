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
  end
end
