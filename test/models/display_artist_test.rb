require 'test_helper'

class DisplayArtistTest < ActiveSupport::TestCase
  test 'owns circles songs and dam songs' do
    artist = create_display_artist
    circle = Circle.create!(name: '関連サークル')
    song = create_song(display_artist: artist)
    dam_song = DamSong.create!(display_artist: artist, title: 'DAM曲', url: 'https://example.com/dam/song')
    artist.circles << circle

    assert_equal [circle], artist.circles.to_a
    assert_equal [song], artist.songs.to_a
    assert_equal [dam_song], artist.dam_songs.to_a
  end

  test 'orders circles by first linked time' do
    artist = create_display_artist
    later_circle = Circle.create!(name: '後から紐づけ')
    earlier_circle = Circle.create!(name: '先に紐づけ')

    DisplayArtistsCircle.create!(display_artist: artist, circle: later_circle, created_at: 1.day.ago)
    DisplayArtistsCircle.create!(display_artist: artist, circle: earlier_circle, created_at: 2.days.ago)

    assert_equal [earlier_circle, later_circle], artist.reload.circles.to_a
  end

  test 'destroys dependent records' do
    artist = create_display_artist
    circle = Circle.create!(name: '関連サークル')
    create_song(display_artist: artist)
    DamSong.create!(display_artist: artist, title: 'DAM曲', url: 'https://example.com/dam/song')
    artist.circles << circle

    assert_difference -> { Song.count }, -1 do
      assert_difference -> { DamSong.count }, -1 do
        assert_difference -> { DisplayArtistsCircle.count }, -1 do
          artist.destroy!
        end
      end
    end

    assert Circle.exists?(circle.id)
  end

  test 'filters by karaoke type scopes' do
    dam = create_display_artist(karaoke_type: 'DAM', name: 'DAM Artist')
    joysound = create_display_artist(karaoke_type: 'JOYSOUND', name: 'JOYSOUND Artist')
    music_post = create_display_artist(karaoke_type: 'JOYSOUND(うたスキ)', name: 'Music Post Artist')

    assert_includes DisplayArtist.dam, dam
    assert_not_includes DisplayArtist.dam, joysound
    assert_includes DisplayArtist.joysound, joysound
    assert_includes DisplayArtist.music_post, music_post
  end

  test 'filters empty name readings' do
    empty = create_display_artist(name_reading: '')
    filled = create_display_artist(name_reading: 'ずん')

    assert_includes DisplayArtist.name_reading_empty, empty
    assert_not_includes DisplayArtist.name_reading_empty, filled
  end

  test 'exposes name as searchable attribute and calculates progress' do
    assert_equal ['name'], DisplayArtist.ransackable_attributes
    assert_equal 96, DisplayArtist.progress_percentage(0, 0)
    assert_equal 52, DisplayArtist.progress_percentage(5, 10)
  end
end
