require 'test_helper'

class SongWithDamOuchikaraokeTest < ActiveSupport::TestCase
  test 'requires song' do
    detail = SongWithDamOuchikaraoke.new(url: 'https://example.com/dam/ouchikaraoke')

    assert_not detail.valid?
    assert_not_empty detail.errors[:song]
  end

  test 'requires url' do
    detail = SongWithDamOuchikaraoke.new(song: create_song, url: '')

    assert_not detail.valid?
    assert detail.errors.added?(:url, :blank)
  end

  test 'belongs to song' do
    song = create_song
    detail = SongWithDamOuchikaraoke.create!(song:, url: 'https://example.com/dam/ouchikaraoke')

    assert_equal song, detail.song
  end

  test 'requires unique song and url' do
    song = create_song
    existing = SongWithDamOuchikaraoke.create!(song:, url: 'https://example.com/dam/ouchikaraoke/unique')

    duplicate_song = SongWithDamOuchikaraoke.new(song:, url: 'https://example.com/dam/ouchikaraoke/other')
    duplicate_url = SongWithDamOuchikaraoke.new(song: create_song, url: existing.url)

    assert_not duplicate_song.valid?
    assert duplicate_song.errors.added?(:song_id, :taken, value: song.id)
    assert_not duplicate_url.valid?
    assert duplicate_url.errors.added?(:url, :taken, value: existing.url)
  end
end
