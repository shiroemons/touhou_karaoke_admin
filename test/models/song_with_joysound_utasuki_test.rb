require 'test_helper'

class SongWithJoysoundUtasukiTest < ActiveSupport::TestCase
  test 'requires song' do
    detail = SongWithJoysoundUtasuki.new(url: 'https://example.com/joysound/utasuki', delivery_deadline_date: Date.current)

    assert_not detail.valid?
    assert_not_empty detail.errors[:song]
  end

  test 'requires url' do
    detail = SongWithJoysoundUtasuki.new(song: create_song, delivery_deadline_date: Date.current, url: '')

    assert_not detail.valid?
    assert detail.errors.added?(:url, :blank)
  end

  test 'belongs to song' do
    song = create_song
    detail = SongWithJoysoundUtasuki.create!(song:, url: 'https://example.com/joysound/utasuki', delivery_deadline_date: Date.current)

    assert_equal song, detail.song
  end

  test 'requires unique song and url' do
    song = create_song
    existing = SongWithJoysoundUtasuki.create!(
      song:,
      url: 'https://example.com/joysound/utasuki/unique',
      delivery_deadline_date: Date.current
    )

    duplicate_song = SongWithJoysoundUtasuki.new(song:, url: 'https://example.com/joysound/utasuki/other', delivery_deadline_date: Date.current)
    duplicate_url = SongWithJoysoundUtasuki.new(song: create_song, url: existing.url, delivery_deadline_date: Date.current)

    assert_not duplicate_song.valid?
    assert duplicate_song.errors.added?(:song_id, :taken, value: song.id)
    assert_not duplicate_url.valid?
    assert duplicate_url.errors.added?(:url, :taken, value: existing.url)
  end
end
