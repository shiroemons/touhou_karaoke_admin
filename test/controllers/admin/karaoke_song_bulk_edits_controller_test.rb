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
      assert_select 'form[data-admin-filter-form]'
      assert_select 'select[name="status"][data-admin-auto-submit]'
      assert_select "input[name=?]", "songs[#{missing_song.id}][original_songs]"
      assert_select '[data-admin-original-song-picker]'
      assert_select '[data-admin-original-song-search]'
      assert_includes response.body, missing_song.title
      assert_not_includes response.body, linked_song.title
    end

    test 'returns original song options for picker search' do
      original_song = create_original_song(title: 'Picker Search Original')

      get admin_karaoke_song_bulk_edit_original_song_options_path(q: 'Picker Search')

      assert_response :success
      payload = response.parsed_body
      assert_equal original_song.title, payload.first.fetch('title')
      assert_includes payload.first.fetch('label'), original_song.title
    end

    test 'returns original song options with minor title notation differences' do
      original_song = create_original_song(title: '最後の一人は慣れてるから　～ Stone Goddess')

      get admin_karaoke_song_bulk_edit_original_song_options_path(q: '最後の一人は慣れてるから 〜Stone')

      assert_response :success
      payload = response.parsed_body
      assert_equal original_song.title, payload.first.fetch('title')
    end

    test 'resolves pasted original song text for picker' do
      original_song = create_original_song(title: 'Picker Resolve Original')

      post admin_karaoke_song_bulk_edit_resolve_original_songs_path, params: { text: "原曲: #{original_song.title}" }, as: :json

      assert_response :success
      payload = response.parsed_body
      assert_equal [original_song.title], payload.fetch('titles')
      assert_empty payload.fetch('errors')
    end

    test 'resolves pasted ampersand separated original song text for picker' do
      master_spark = create_original_song(title: '恋色マスタースパーク')
      dream_battle = create_original_song(title: '少女綺想曲　～ Dream Battle')

      post admin_karaoke_song_bulk_edit_resolve_original_songs_path,
           params: { text: '恋色マスタースパーク＆少女綺想曲 ～ Dream Battle' },
           as: :json

      assert_response :success
      payload = response.parsed_body
      assert_equal [master_spark.title, dream_battle.title], payload.fetch('titles')
      assert_empty payload.fetch('errors')
    end

    test 'does not return partial picker resolution when a pasted original song is unknown' do
      create_original_song(title: 'Picker Known Original')

      post admin_karaoke_song_bulk_edit_resolve_original_songs_path,
           params: { text: 'Picker Missing Original / Picker Known Original' },
           as: :json

      assert_response :success
      payload = response.parsed_body
      assert_empty payload.fetch('titles')
      assert_equal ['Picker Missing Original', 'Picker Known Original'], payload.fetch('items').pluck('input_title')
      assert_equal ['Picker Missing Original', 'Picker Known Original'], payload.fetch('items').pluck('title')
      assert_equal [false, true], payload.fetch('items').pluck('exists')
      assert_equal '原曲「Picker Missing Original」が見つかりません。', payload.fetch('items').first.fetch('error')
      assert_equal 1, payload.fetch('errors').size
      assert_match(/Picker Missing Original/, payload.fetch('errors').first)
    end

    test 'returns original song candidates when picker resolution fails' do
      original_song = create_original_song(title: '少女綺想曲　～ Dream Battle')

      post admin_karaoke_song_bulk_edit_resolve_original_songs_path,
           params: { text: '少女綺想曲 Dream Battle Extra' },
           as: :json

      assert_response :success
      payload = response.parsed_body
      assert_empty payload.fetch('titles')
      assert_equal original_song.title, payload.fetch('items').first.fetch('candidates').first.fetch('title')
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

    test 'previews multiple original song links without updating records' do
      song = create_song(title: 'Controller Preview Song')
      first_original_song = create_original_song(title: 'Controller Preview First')
      second_original_song = create_original_song(title: 'Controller Preview Second')

      post admin_karaoke_song_bulk_edit_path, params: {
        mode: 'preview',
        songs: {
          song.id => {
            original_songs: "#{first_original_song.title}/#{second_original_song.title}",
            youtube_url: 'https://youtube.example/preview'
          }
        }
      }

      assert_response :success
      assert_select 'h2', text: '原曲紐づけチェック結果'
      assert_select '.admin-original-song-preview-row', text: /Controller Preview Song/
      assert_select '.admin-original-song-preview-row li', text: /#{first_original_song.code}/
      assert_select '.admin-original-song-preview-row li', text: /#{second_original_song.code}/
      assert_select '.admin-original-song-preview-row li', text: /Controller Preview First/
      assert_select '.admin-original-song-preview-row li', text: /Controller Preview Second/
      assert_empty song.reload.original_songs
      assert_equal '', song.youtube_url
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
