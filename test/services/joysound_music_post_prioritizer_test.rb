# frozen_string_literal: true

require 'test_helper'

class JoysoundMusicPostPrioritizerTest < ActiveSupport::TestCase
  test 'returns unmatched posts before upcoming posts without duplicates' do
    matched_song = create_song(
      display_artist: create_display_artist(karaoke_type: 'JOYSOUND(うたスキ)'),
      karaoke_type: 'JOYSOUND(うたスキ)',
      url: 'https://example.com/prioritizer/matched'
    )
    JoysoundMusicPost.create!(
      title: 'Matched Prioritizer',
      artist: 'ZUN',
      producer: 'p',
      delivery_deadline_on: 2.months.from_now.to_date,
      url: 'https://example.com/post/prioritizer-matched',
      joysound_url: matched_song.url
    )
    unmatched = JoysoundMusicPost.create!(
      title: 'Unmatched Prioritizer',
      artist: 'ZUN',
      producer: 'p',
      delivery_deadline_on: 2.months.from_now.to_date,
      url: 'https://example.com/post/prioritizer-unmatched',
      joysound_url: 'https://example.com/prioritizer/unmatched'
    )
    upcoming = JoysoundMusicPost.create!(
      title: 'Upcoming Prioritizer',
      artist: 'ZUN',
      producer: 'p',
      delivery_deadline_on: 1.week.from_now.to_date,
      url: 'https://example.com/post/prioritizer-upcoming',
      joysound_url: 'https://example.com/prioritizer/upcoming'
    )

    result = JoysoundMusicPostPrioritizer.call

    assert_operator result.index(unmatched), :<, result.index(upcoming)
    assert_includes result, upcoming
    assert_equal result.uniq, result
  end
end
