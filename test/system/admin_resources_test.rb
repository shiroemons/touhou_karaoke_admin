require 'application_system_test_case'

class AdminResourcesTest < ApplicationSystemTestCase
  driven_by :rack_test

  setup do
    original = create_original(title: '東方紅魔郷', short_title: '紅')
    original_song = create_original_song(original:, title: '赤より紅い夢')
    artist = create_display_artist(name: 'ZUN', name_reading: 'ずん')
    @song = create_song(display_artist: artist, title: 'Karaoke Song System Test')
    @song.original_songs << original_song
  end

  test 'admin dashboard links to songs index' do
    visit admin_root_path

    assert_text '管理画面'
    click_on 'カラオケ配信曲', match: :first

    assert_current_path admin_songs_path, ignore_query: true
    assert_text 'カラオケ配信曲'
    assert_text @song.title
  end

  test 'songs index supports search clear and show navigation' do
    other_song = create_song(title: 'Unmatched System Test Song')

    visit admin_songs_path(view_mode: 'paginated')
    assert_text @song.title
    assert_text other_song.title

    fill_in 'q', with: @song.title
    click_on '検索'

    assert_text @song.title
    assert_no_text other_song.title

    click_on 'クリア'
    assert_text other_song.title

    click_on @song.title
    assert_current_path admin_song_path(@song), ignore_query: true
    assert_text @song.title
    assert_text '赤より紅い夢'
  end
end
