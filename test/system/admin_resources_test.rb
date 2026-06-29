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

  test 'songs index keeps filters sort and pagination together' do
    original = create_original(title: '東方妖々夢', short_title: '妖')
    original_song = create_original_song(original:, title: '幽雅に咲かせ、墨染の桜')
    dam_artist = create_display_artist(karaoke_type: 'DAM', name: 'Combo DAM Artist')
    joysound_artist = create_display_artist(karaoke_type: 'JOYSOUND', name: 'Combo JOYSOUND Artist')

    25.times do |index|
      song = create_song(
        display_artist: dam_artist,
        karaoke_type: 'DAM',
        title: format('Combo Filter Song %02d', index + 1)
      )
      song.original_songs << original_song
    end
    create_song(display_artist: joysound_artist, karaoke_type: 'JOYSOUND', title: 'Combo Filter Song JOYSOUND')

    visit admin_songs_path(
      view_mode: 'paginated',
      per_page: 24,
      sort: 'title',
      direction: 'asc',
      q: 'Combo Filter',
      filters: { karaoke_type: 'dam', original_link: 'linked' }
    )

    assert_text 'Combo Filter Song 01'
    assert_text 'Combo Filter Song 24'
    assert_no_text 'Combo Filter Song 25'
    assert_no_text 'Combo Filter Song JOYSOUND'

    click_on '次へ'

    assert_text 'Combo Filter Song 25'
    assert_no_text 'Combo Filter Song 01'
    assert_current_path(
      admin_songs_path(
        view_mode: 'paginated',
        per_page: 24,
        sort: 'title',
        direction: 'asc',
        q: 'Combo Filter',
        filters: { karaoke_type: 'dam', original_link: 'linked' },
        page: 2
      ),
      ignore_query: false
    )
  end

  test 'songs infinite scroll next url preserves index query' do
    dam_artist = create_display_artist(karaoke_type: 'DAM', name: 'Infinite DAM Artist')
    25.times do |index|
      create_song(
        display_artist: dam_artist,
        karaoke_type: 'DAM',
        title: format('Infinite Filter Song %02d', index + 1)
      )
    end

    visit admin_songs_path(
      view_mode: 'infinite',
      per_page: 24,
      sort: 'title',
      direction: 'asc',
      q: 'Infinite Filter',
      filters: { karaoke_type: 'dam' }
    )

    next_url = find('[data-admin-infinite-scroll]')['data-next-url']

    assert_includes next_url, 'partial=rows'
    assert_includes next_url, 'page=2'
    assert_includes next_url, 'view_mode=infinite'
    assert_includes next_url, 'sort=title'
    assert_includes next_url, 'direction=asc'
    assert_includes next_url, 'q=Infinite+Filter'
    assert_includes next_url, 'filters%5Bkaraoke_type%5D=dam'
  end
end
