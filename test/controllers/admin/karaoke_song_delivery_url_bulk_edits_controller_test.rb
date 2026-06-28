require 'test_helper'

module Admin
  class KaraokeSongDeliveryUrlBulkEditsControllerTest < ActionDispatch::IntegrationTest
    test 'shows all song rows with delivery url columns' do
      linked_song = create_song(title: 'Delivery URL Linked Song')
      linked_song.original_songs << create_original_song(title: 'Delivery URL Linked Original')
      missing_song = create_song(title: 'Delivery URL Missing Song')

      get admin_karaoke_song_delivery_url_bulk_edit_path

      assert_response :success
      assert_select 'h1', text: 'カラオケ配信URL編集'
      KaraokeSongDeliveryUrlBulkEditor::COLUMNS.each do |column|
        assert_select 'th', text: column
      end
      assert_select "input[name=?]", "songs[#{linked_song.id}][youtube_url]"
      assert_select "input[name=?]", "songs[#{linked_song.id}][line_music_url]"
      assert_select "input[name=?][placeholder=?]", "songs[#{linked_song.id}][youtube_url]", 'https://www.youtube.com/watch?v=...'
      assert_select "input[name=?][placeholder=?]", "songs[#{linked_song.id}][line_music_url]", 'https://music.line.me/webapp/track/...'
      assert_select 'form[data-admin-filter-form]'
      assert_select '.admin-delivery-url-control-group h2', text: '絞り込み'
      assert_select '.admin-delivery-url-control-group h2', text: '並び替え'
      assert_select 'input[name="missing_url_columns[]"][value="youtube_url"][data-admin-auto-submit]'
      assert_select 'select[name="karaoke_type"][data-admin-auto-submit]'
      assert_select 'select[name="sort"][data-admin-auto-submit] option[selected][value="created_at"]'
      assert_select 'select[name="direction"][data-admin-auto-submit] option[selected][value="desc"]'
      assert_includes response.body, linked_song.title
      assert_includes response.body, missing_song.title
      assert_includes response.body, 'Delivery URL Linked Original'
      assert_select 'a[href=?]', admin_karaoke_song_bulk_edit_path(status: 'all'), text: /カラオケ楽曲紐づけ/
    end

    test 'filters songs by missing delivery url columns' do
      missing_youtube_song = create_song(title: 'Missing YouTube URL Song', youtube_url: '', spotify_url: '')
      filled_youtube_song = create_song(title: 'Filled YouTube URL Song', youtube_url: 'https://youtube.example/watch', spotify_url: '')
      filled_spotify_song = create_song(title: 'Filled Spotify URL Song', youtube_url: '', spotify_url: 'https://open.spotify.example/track')

      get admin_karaoke_song_delivery_url_bulk_edit_path, params: { missing_url_columns: ['youtube_url'] }

      assert_response :success
      assert_includes response.body, missing_youtube_song.title
      assert_not_includes response.body, filled_youtube_song.title
      assert_includes response.body, filled_spotify_song.title
      assert_select 'input[name="missing_url_columns[]"][value="youtube_url"][checked]'
      assert_select 'label.admin-url-filter-option-active', text: /youtube_url 設定済みを非表示/

      get admin_karaoke_song_delivery_url_bulk_edit_path, params: { missing_url_columns: %w[youtube_url spotify_url] }

      assert_response :success
      assert_includes response.body, missing_youtube_song.title
      assert_not_includes response.body, filled_youtube_song.title
      assert_not_includes response.body, filled_spotify_song.title
      assert_select 'input[name="missing_url_columns[]"][value="youtube_url"][checked]'
      assert_select 'input[name="missing_url_columns[]"][value="spotify_url"][checked]'
      assert_select 'label.admin-url-filter-option-active', count: 2
    end

    test 'filters songs by karaoke type' do
      dam_artist = create_display_artist(karaoke_type: 'DAM', name: 'DAM Filter Artist')
      joysound_artist = create_display_artist(karaoke_type: 'JOYSOUND', name: 'JOYSOUND Filter Artist')
      dam_song = create_song(display_artist: dam_artist, title: 'DAM Karaoke Type Filter Song')
      joysound_song = create_song(display_artist: joysound_artist, title: 'JOYSOUND Karaoke Type Filter Song')

      get admin_karaoke_song_delivery_url_bulk_edit_path, params: { karaoke_type: 'DAM' }

      assert_response :success
      assert_includes response.body, dam_song.title
      assert_not_includes response.body, joysound_song.title
      assert_select 'select[name="karaoke_type"] option[selected][value="DAM"]'
    end

    test 'sorts songs by selected delivery url sort order' do
      older_song = create_song(title: 'Older Registered Song', youtube_url: 'https://youtube.example/b', created_at: 2.days.ago)
      newer_song = create_song(title: 'Newer Registered Song', youtube_url: 'https://youtube.example/a', created_at: 1.day.ago)

      get admin_karaoke_song_delivery_url_bulk_edit_path

      assert_response :success
      assert_operator response.body.index(newer_song.title), :<, response.body.index(older_song.title)

      get admin_karaoke_song_delivery_url_bulk_edit_path, params: { sort: 'youtube_url', direction: 'asc' }

      assert_response :success
      assert_operator response.body.index(newer_song.title), :<, response.body.index(older_song.title)
      assert_select 'select[name="sort"] option[selected][value="youtube_url"]'
      assert_select 'select[name="direction"] option[selected][value="asc"]'
    end

    test 'updates visible form rows' do
      song = create_song(title: 'Controller Delivery URL Song')
      original_song = create_original_song(title: 'Controller Delivery URL Original')
      song.original_songs << original_song

      post admin_karaoke_song_delivery_url_bulk_edit_path(missing_url_columns: ['youtube_url']), params: {
        songs: {
          song.id => {
            youtube_url: 'https://youtube.example/controller',
            nicovideo_url: '',
            apple_music_url: '',
            youtube_music_url: '',
            spotify_url: 'https://open.spotify.example/controller',
            line_music_url: 'https://music.line.example/controller'
          }
        }
      }

      assert_redirected_to admin_karaoke_song_delivery_url_bulk_edit_path(missing_url_columns: ['youtube_url'])
      follow_redirect!
      assert_select '.admin-flash-notice', text: '更新が完了しました。更新件数: 1件、変更なし: 0件'
      assert_equal [original_song], song.reload.original_songs.to_a
      assert_equal 'https://youtube.example/controller', song.youtube_url
      assert_equal 'https://open.spotify.example/controller', song.spotify_url
      assert_equal 'https://music.line.example/controller', song.line_music_url
    end

    test 'previews delivery url changes without updating records' do
      song = create_song(title: 'Controller Delivery URL Preview Song', youtube_url: '')

      post admin_karaoke_song_delivery_url_bulk_edit_path, params: {
        mode: 'preview',
        songs: {
          song.id => {
            youtube_url: 'https://youtube.example/preview',
            nicovideo_url: '',
            apple_music_url: '',
            youtube_music_url: '',
            spotify_url: '',
            line_music_url: ''
          }
        }
      }

      assert_response :success
      assert_select 'h2', text: '配信URL更新チェック結果'
      assert_select '.admin-delivery-url-preview-row', text: /Controller Delivery URL Preview Song/
      assert_select '.admin-delivery-url-preview-row code', text: /youtube_url/
      assert_select '.admin-delivery-url-preview-row strong', text: %r{https://youtube.example/preview}
      assert_equal '', song.reload.youtube_url
    end

    test 'updates from pasted delivery url tsv' do
      song = create_song(title: 'Controller Delivery URL TSV Song')
      tsv = [
        KaraokeSongDeliveryUrlBulkEditor::COLUMNS.join("\t"),
        [
          song.id,
          song.karaoke_type,
          song.display_artist.name,
          song.title,
          '',
          '',
          '',
          'https://music.apple.example/controller',
          '',
          'https://open.spotify.example/controller',
          'https://music.line.example/controller'
        ].join("\t")
      ].join("\n")

      post admin_karaoke_song_delivery_url_bulk_edit_path, params: { bulk_tsv: tsv }

      assert_redirected_to admin_karaoke_song_delivery_url_bulk_edit_path
      assert_equal 'https://music.apple.example/controller', song.reload.apple_music_url
      assert_equal 'https://open.spotify.example/controller', song.spotify_url
      assert_equal 'https://music.line.example/controller', song.line_music_url
    end

    test 'redirects with errors when pasted tsv has unknown song id' do
      song = create_song(title: 'Controller Delivery URL Invalid TSV Song', youtube_url: '')
      tsv = [
        KaraokeSongDeliveryUrlBulkEditor::COLUMNS.join("\t"),
        [
          'missing-song-id',
          song.karaoke_type,
          song.display_artist.name,
          song.title,
          '',
          'https://youtube.example/not-applied',
          '',
          '',
          '',
          '',
          ''
        ].join("\t")
      ].join("\n")

      post admin_karaoke_song_delivery_url_bulk_edit_path, params: { bulk_tsv: tsv }

      assert_redirected_to admin_karaoke_song_delivery_url_bulk_edit_path
      follow_redirect!
      assert_select '.admin-flash-alert', /missing-song-id/
      assert_equal '', song.reload.youtube_url
    end
  end
end
