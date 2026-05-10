require 'test_helper'

class OriginalSongTest < ActiveSupport::TestCase
  test 'uses code as primary key and belongs to original by code' do
    original = create_original(code: 'th06', short_title: '紅')
    song = create_original_song(original:, code: 'th06-01')

    assert_equal 'th06-01', song.id
    assert_equal original, song.original
    assert_equal '紅', song.original_short_title
  end

  test 'destroys join records when destroyed' do
    original_song = create_original_song
    song = create_song
    song.original_songs << original_song

    assert_difference -> { SongsOriginalSong.count }, -1 do
      original_song.destroy!
    end

    assert Song.exists?(song.id)
  end

  test 'filters non duplicated songs' do
    normal = create_original_song(title: '通常原曲', is_duplicate: false)
    duplicate = create_original_song(title: '重複原曲', is_duplicate: true)

    assert_includes OriginalSong.non_duplicated, normal
    assert_not_includes OriginalSong.non_duplicated, duplicate
  end

  test 'exposes title as searchable attribute' do
    assert_equal ['title'], OriginalSong.ransackable_attributes
  end
end
