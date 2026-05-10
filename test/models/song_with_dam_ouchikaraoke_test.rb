require 'test_helper'

class SongWithDamOuchikaraokeTest < ActiveSupport::TestCase
  test 'requires song' do
    detail = SongWithDamOuchikaraoke.new(url: 'https://example.com/dam/ouchikaraoke')

    assert_not detail.valid?
    assert_not_empty detail.errors[:song]
  end

  test 'belongs to song' do
    song = create_song
    detail = SongWithDamOuchikaraoke.create!(song:, url: 'https://example.com/dam/ouchikaraoke')

    assert_equal song, detail.song
  end
end
