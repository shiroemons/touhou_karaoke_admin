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

  test 'treats posts as upcoming with the same 30-day window as the admin deadline cards' do
    matched_post = lambda do |suffix, deadline|
      song = create_song(
        display_artist: create_display_artist(karaoke_type: 'JOYSOUND(うたスキ)'),
        karaoke_type: 'JOYSOUND(うたスキ)',
        url: "https://example.com/prioritizer/window-#{suffix}"
      )
      JoysoundMusicPost.create!(
        title: "Window #{suffix}",
        artist: 'ZUN',
        producer: 'p',
        delivery_deadline_on: deadline,
        url: "https://example.com/post/window-#{suffix}",
        joysound_url: song.url
      )
    end
    expired = matched_post.call('expired', Admin::DeliveryDeadlineWindows.current_date - 1)
    day30 = matched_post.call('day30', Admin::DeliveryDeadlineWindows.current_date + 30)
    day31 = matched_post.call('day31', Admin::DeliveryDeadlineWindows.current_date + 31)

    result = JoysoundMusicPostPrioritizer.call

    assert_includes result, expired
    assert_includes result, day30
    assert_not_includes result, day31
    assert Admin::DeliveryDeadlineWindows.fetch(:within_30_days).range(Admin::DeliveryDeadlineWindows.current_date).cover?(day30.delivery_deadline_on)
    assert_not Admin::DeliveryDeadlineWindows.fetch(:within_30_days).range(Admin::DeliveryDeadlineWindows.current_date).cover?(day31.delivery_deadline_on)
  end
end
