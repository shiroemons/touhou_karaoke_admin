# frozen_string_literal: true

require 'test_helper'

module Admin
  class KaraokeSongDeliveryUrlBulkEditQueryTest < ActiveSupport::TestCase
    test 'filters sorts and normalizes index params' do
      dam_artist = create_display_artist(karaoke_type: 'DAM', name: 'Delivery Query Artist')
      matching_song = create_song(display_artist: dam_artist, title: 'Delivery Query Match', youtube_url: '', spotify_url: '')
      create_song(display_artist: dam_artist, title: 'Delivery Query Filled', youtube_url: 'https://youtube.example/filled', spotify_url: '')

      query = KaraokeSongDeliveryUrlBulkEditQuery.new(
        scope: Song.all,
        params: {
          q: 'Delivery Query',
          missing_url_columns: %w[youtube_url invalid],
          karaoke_type: 'DAM',
          sort: 'title',
          direction: 'asc',
          page: '1'
        },
        karaoke_type_options: ['DAM']
      )

      assert_equal [matching_song], query.songs.to_a
      assert_equal ['youtube_url'], query.missing_url_columns
      assert_equal 'DAM', query.karaoke_type
      assert_equal 'title', query.sort
      assert_equal 'asc', query.direction
      assert_equal(
        {
          q: 'Delivery Query',
          missing_url_columns: ['youtube_url'],
          karaoke_type: 'DAM',
          sort: 'title',
          direction: 'asc',
          page: '1'
        },
        query.index_params
      )
    end

    test 'falls back invalid scalar params' do
      query = KaraokeSongDeliveryUrlBulkEditQuery.new(
        scope: Song.all,
        params: {
          karaoke_type: 'UNKNOWN',
          sort: 'invalid',
          direction: 'sideways',
          page: '-3'
        },
        karaoke_type_options: ['DAM']
      )

      assert_nil query.karaoke_type
      assert_equal 'created_at', query.sort
      assert_equal 'desc', query.direction
      assert_equal 1, query.page
    end
  end
end
