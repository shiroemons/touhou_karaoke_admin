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
