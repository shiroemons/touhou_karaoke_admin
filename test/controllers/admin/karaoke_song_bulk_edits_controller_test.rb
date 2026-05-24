require 'test_helper'

module Admin
  class KaraokeSongBulkEditsControllerTest < ActionDispatch::IntegrationTest
    test 'shows missing original song rows in export column order' do
      artist = create_display_artist(name: 'Bulk Table Artist')
      missing_song = create_song(display_artist: artist, title: 'Bulk Missing Song')
      linked_song = create_song(display_artist: artist, title: 'Bulk Linked Song')
      linked_song.original_songs << create_original_song(title: 'Already Linked Original')

      get admin_karaoke_song_bulk_edit_path

      assert_response :success
      assert_select 'h1', text: 'カラオケ楽曲紐づけ'
      KaraokeSongBulkEditor::COLUMNS.each do |column|
        assert_select 'th', text: column
      end
      assert_select "input[name=?]", "songs[#{missing_song.id}][original_songs]"
      assert_includes response.body, missing_song.title
      assert_not_includes response.body, linked_song.title
    end

    test 'updates visible form rows' do
      song = create_song(title: 'Controller Bulk Song')
      original_song = create_original_song(title: 'Controller Bulk Original')

      post admin_karaoke_song_bulk_edit_path, params: {
        songs: {
          song.id => {
            original_songs: original_song.title,
            youtube_url: 'https://youtube.example/controller',
            nicovideo_url: '',
            apple_music_url: '',
            youtube_music_url: '',
            spotify_url: '',
            line_music_url: ''
          }
        }
      }

      assert_redirected_to admin_karaoke_song_bulk_edit_path(status: 'missing')
      follow_redirect!
      assert_select '.admin-flash-notice', text: '更新が完了しました。更新件数: 1件、変更なし: 0件'
      assert_equal [original_song], song.reload.original_songs.to_a
      assert_equal 'https://youtube.example/controller', song.youtube_url
    end

    test 'updates from pasted export tsv' do
      song = create_song(title: 'Controller TSV Song')
      original_song = create_original_song(title: 'Controller TSV Original')
      tsv = [
        KaraokeSongBulkEditor::COLUMNS.join("\t"),
        [
          song.id,
          song.karaoke_type,
          song.display_artist.name,
          song.title,
          original_song.title,
          '',
          '',
          'https://music.apple.example/controller',
          '',
          '',
          ''
        ].join("\t")
      ].join("\n")

      post admin_karaoke_song_bulk_edit_path, params: { bulk_tsv: tsv }

      assert_redirected_to admin_karaoke_song_bulk_edit_path(status: 'missing')
      assert_equal [original_song], song.reload.original_songs.to_a
      assert_equal 'https://music.apple.example/controller', song.apple_music_url
    end

    test 'redirects with errors when pasted tsv has unknown original song' do
      song = create_song(title: 'Controller Invalid TSV Song')
      tsv = [
        KaraokeSongBulkEditor::COLUMNS.join("\t"),
        [
          song.id,
          song.karaoke_type,
          song.display_artist.name,
          song.title,
          'Unknown Controller Original',
          'https://youtube.example/not-applied',
          '',
          '',
          '',
          '',
          ''
        ].join("\t")
      ].join("\n")

      post admin_karaoke_song_bulk_edit_path, params: { bulk_tsv: tsv }

      assert_redirected_to admin_karaoke_song_bulk_edit_path(status: 'missing')
      follow_redirect!
      assert_select '.admin-flash-alert', /Unknown Controller Original/
      assert_empty song.reload.original_songs
      assert_equal '', song.youtube_url
    end
  end
end
