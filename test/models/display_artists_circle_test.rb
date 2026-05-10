require 'test_helper'

class DisplayArtistsCircleTest < ActiveSupport::TestCase
  test 'requires display artist and circle' do
    join = DisplayArtistsCircle.new

    assert_not join.valid?
    assert_not_empty join.errors[:display_artist]
    assert_not_empty join.errors[:circle]
  end

  test 'connects a display artist to a circle' do
    artist = create_display_artist
    circle = Circle.create!(name: '関連サークル')
    join = DisplayArtistsCircle.create!(display_artist: artist, circle:)

    assert_equal artist, join.display_artist
    assert_equal circle, join.circle
  end
end
