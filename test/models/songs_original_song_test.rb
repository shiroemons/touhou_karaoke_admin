require 'test_helper'

class SongsOriginalSongTest < ActiveSupport::TestCase
  test 'requires song and original song' do
    join = SongsOriginalSong.new

    assert_not join.valid?
    assert_not_empty join.errors[:song]
    assert_not_empty join.errors[:original_song]
  end

  test 'connects song to original song by code' do
    song = create_song
    original_song = create_original_song(code: 'th06-01')
    join = SongsOriginalSong.create!(song:, original_song:)

    assert_equal song, join.song
    assert_equal original_song, join.original_song
    assert_equal 'th06-01', join.original_song_code
  end
end
