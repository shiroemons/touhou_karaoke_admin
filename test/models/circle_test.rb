require 'test_helper'

class CircleTest < ActiveSupport::TestCase
  test 'connects display artists and songs through join records' do
    circle = Circle.create!(name: '上海アリス幻樂団')
    artist = create_display_artist
    song = create_song(display_artist: artist)

    circle.display_artists << artist

    assert_equal [artist], circle.display_artists.to_a
    assert_equal [song], circle.songs.to_a
    assert_equal 1, circle.display_artists_count
    assert_equal 1, circle.songs_count
  end

  test 'orders display artists by first linked time' do
    circle = Circle.create!(name: '並び順サークル')
    later_artist = create_display_artist(name: '後から紐づけ')
    earlier_artist = create_display_artist(name: '先に紐づけ')

    DisplayArtistsCircle.create!(display_artist: later_artist, circle:, created_at: 1.day.ago)
    DisplayArtistsCircle.create!(display_artist: earlier_artist, circle:, created_at: 2.days.ago)

    assert_equal [earlier_artist, later_artist], circle.reload.display_artists.to_a
  end

  test 'destroys join records when destroyed' do
    circle = Circle.create!(name: '削除対象サークル')
    artist = create_display_artist
    circle.display_artists << artist

    assert_difference -> { DisplayArtistsCircle.count }, -1 do
      circle.destroy!
    end

    assert DisplayArtist.exists?(artist.id)
  end

  test 'exposes only searchable attributes for ransack' do
    assert_equal ['name'], Circle.ransackable_attributes
  end
end
