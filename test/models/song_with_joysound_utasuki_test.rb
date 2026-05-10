require 'test_helper'

class SongWithJoysoundUtasukiTest < ActiveSupport::TestCase
  test 'requires song' do
    detail = SongWithJoysoundUtasuki.new(url: 'https://example.com/joysound/utasuki', delivery_deadline_date: Date.current)

    assert_not detail.valid?
    assert_not_empty detail.errors[:song]
  end

  test 'belongs to song' do
    song = create_song
    detail = SongWithJoysoundUtasuki.create!(song:, url: 'https://example.com/joysound/utasuki', delivery_deadline_date: Date.current)

    assert_equal song, detail.song
  end
end
