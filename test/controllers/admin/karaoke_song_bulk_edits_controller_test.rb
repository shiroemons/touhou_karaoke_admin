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
      assert_select 'a.admin-nav-link-active[aria-current="page"]', text: /カラオケ楽曲紐づけ/
      KaraokeSongBulkEditor::COLUMNS.each do |column|
        assert_select 'th[title=?]', column, text: KaraokeSongTsvColumns.label(column)
      end
      assert_select 'textarea[name="bulk_tsv"]' do |elements|
        assert_equal KaraokeSongTsvColumns.labels(KaraokeSongBulkEditor::COLUMNS).join("\t"), elements.first['placeholder']
        assert_equal '原曲紐づけTSV', elements.first['aria-label']
        assert_equal 'admin-karaoke-song-bulk-tsv-help', elements.first['aria-describedby']
      end
      assert_select '#admin-karaoke-song-bulk-tsv-help', text: /TSVのヘッダー行とデータ行を貼り付けると、表示中の入力欄へ反映できます。/
      assert_select '#admin-karaoke-song-bulk-tsv-help', text: /Shiftキーを押しながら貼り付けると、各レコードへ展開します。/
      assert_select 'form[data-admin-filter-form]'
      assert_select '.admin-search-field .admin-sr-only', text: 'キーワード'
      assert_select 'input[type="search"][name="q"][aria-label="カラオケ楽曲紐づけをキーワード検索"]'
      assert_select 'select[name="status"][aria-label="表示対象"][data-admin-auto-submit]'
      assert_select 'select[name="per_page"][aria-label="1ページの表示件数"][data-admin-auto-submit] option[selected][value="25"]'
      assert_select 'select[name="per_page"] option[value="25"]'
      assert_select 'select[name="per_page"] option[value="50"]'
      assert_select 'select[name="per_page"] option[value="100"]'
      assert_select '.admin-bulk-apply-warning.alert.alert-warning', text: '反映はDBを更新するため、先に紐づけチェックで内容を確認してください。'
      assert_select '#admin-karaoke-song-bulk-update-note', text: '反映はDBを更新するため、先に紐づけチェックで内容を確認してください。'
      assert_select 'button[aria-label="原曲紐づけチェックを実行"][name="mode"][value="preview"]'
      assert_select 'button.btn-warning[data-turbo-confirm=?]', 'カラオケ楽曲の紐づけとURLをDBに反映します。チェック結果を確認済みですか？'
      assert_select 'button[aria-label="原曲紐づけとURLをDBに反映"][aria-describedby="admin-karaoke-song-bulk-update-note"][name="mode"][value="update"][disabled]'
      assert_select "input[name=?]", "songs[#{missing_song.id}][original_songs]"
      assert_select "input[name=?][placeholder=?]", "songs[#{missing_song.id}][youtube_url]", 'https://www.youtube.com/watch?v=...'
      assert_select "input[name=?][placeholder=?]", "songs[#{missing_song.id}][spotify_url]", 'https://open.spotify.com/track/...'
      assert_select "input[aria-label=?][placeholder=?]", "#{missing_song.title}の原曲を検索", '原曲を検索'
      assert_select "input[name=?][aria-label=?]", "songs[#{missing_song.id}][youtube_url]", "#{missing_song.title}のYouTube URL"
      assert_select "input[name=?][aria-label=?]", "songs[#{missing_song.id}][spotify_url]", "#{missing_song.title}のSpotify URL"
      assert_select 'button.admin-copy-button[data-admin-copy-text=?][aria-label=?]', missing_song.display_artist.name, "#{missing_song.display_artist.name}をコピー"
      assert_select 'a[data-admin-copy-text]', count: 0
      assert_select 'a[href=?]', admin_song_path(missing_song), text: missing_song.title
      assert_select '[data-admin-original-song-picker]'
      assert_select '[data-admin-original-song-search]'
      assert_select '[data-admin-original-song-picker-status][role="status"][aria-live="polite"][aria-atomic="true"]'
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

    test 'shows empty state when no songs match filters' do
      get admin_karaoke_song_bulk_edit_path, params: { q: '一致しない紐づけ検索語' }

      assert_response :success
      assert_select 'tbody tr', 0
      assert_select '.admin-empty-state.alert[role="status"] p', text: '条件に一致する楽曲がありません'
      assert_select '.admin-empty-state.alert a[href=?]', admin_karaoke_song_bulk_edit_path, text: /条件をクリア/
    end

    test 'labels pagination navigation' do
      artist = create_display_artist(name: 'Bulk Pagination Artist')
      101.times { |index| create_song(display_artist: artist, title: "Bulk Pagination Song #{index}") }

      get admin_karaoke_song_bulk_edit_path, params: { per_page: 50 }

      assert_response :success
      assert_select '.admin-pagination[aria-label="カラオケ楽曲紐づけのページ移動"] span[aria-current="page"]', text: %r{1 / \d+}
      assert_select 'select[name="per_page"] option[selected][value="50"]'
      assert_select '.admin-result-summary', text: %r{表示中\s+50\s+/ .* 件}
      assert_select 'a[href*="per_page=50"]', text: /次へ/
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

    test 'resolves newline separated original song text for picker' do
      first_original_song = create_original_song(title: '改行貼り付け原曲1')
      second_original_song = create_original_song(title: '改行貼り付け原曲2')

      post admin_karaoke_song_bulk_edit_resolve_original_songs_path,
           params: { text: "#{first_original_song.title}\n#{second_original_song.title}" },
           as: :json

      assert_response :success
      payload = response.parsed_body
      assert_equal [first_original_song.title, second_original_song.title], payload.fetch('titles')
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

      post admin_karaoke_song_bulk_edit_path(per_page: 50), params: {
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

      assert_redirected_to admin_karaoke_song_bulk_edit_path(status: 'missing', per_page: 50)
      follow_redirect!
      assert_select '.admin-flash-notice', text: '更新が完了しました。更新件数: 1件、変更なし: 0件'
      assert_equal [original_song], song.reload.original_songs.to_a
      assert_equal 'https://youtube.example/controller', song.youtube_url
    end

    test 'bulk updates invalidate dashboard counts' do
      song = create_song(title: 'Controller Bulk Cache Song')
      original_song = create_original_song(title: 'Controller Bulk Cache Original')

      with_cache_store(ActiveSupport::Cache::MemoryStore.new) do
        Rails.cache.write(DashboardCache::KEY, { total_songs: 1 })
        post admin_karaoke_song_bulk_edit_path, params: {
          songs: { song.id => { original_songs: original_song.title, youtube_url: 'https://youtube.example/cache' } }
        }

        assert_redirected_to admin_karaoke_song_bulk_edit_path(status: 'missing')
        assert_not Rails.cache.exist?(DashboardCache::KEY)
      end
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
      assert_select '#admin-karaoke-song-bulk-update-note', text: 'チェック結果を確認済みです。反映すると表示中の入力内容でDBを更新します。'
      assert_select 'button[aria-label="原曲紐づけとURLをDBに反映"][name="mode"][value="update"][disabled]', false
      assert_empty song.reload.original_songs
      assert_equal '', song.youtube_url
    end

    test 'preview retains submitted original song and youtube url values in rendered fields' do
      song = create_song(title: 'Controller Preview Retains Song')
      first_original_song = create_original_song(title: 'Controller Preview Retains First')
      second_original_song = create_original_song(title: 'Controller Preview Retains Second')

      post admin_karaoke_song_bulk_edit_path, params: {
        mode: 'preview',
        songs: {
          song.id => {
            original_songs: "#{first_original_song.title}/#{second_original_song.title}",
            youtube_url: 'https://youtube.example/preview-retained'
          }
        }
      }

      assert_response :success
      assert_select 'input[name=?][value=?]', "songs[#{song.id}][original_songs]", "#{first_original_song.title}/#{second_original_song.title}"
      assert_select 'input[name=?][value=?]', "songs[#{song.id}][youtube_url]", 'https://youtube.example/preview-retained'
    end

    test 'preview shows submitted original song value instead of previously linked db value' do
      song = create_song(title: 'Controller Preview Already Linked Song', youtube_url: 'https://youtube.example/existing-before-clear')
      song.original_songs << create_original_song(title: 'Controller Preview Existing Original')
      replacement_original_song = create_original_song(title: 'Controller Preview Replacement Original')

      post admin_karaoke_song_bulk_edit_path, params: {
        mode: 'preview',
        status: 'all',
        songs: {
          song.id => {
            original_songs: replacement_original_song.title,
            youtube_url: ''
          }
        }
      }

      assert_response :success
      assert_select 'input[name=?][value=?]', "songs[#{song.id}][original_songs]", replacement_original_song.title
      assert_select 'input[name=?][value=?]', "songs[#{song.id}][youtube_url]", ''
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

    test 'updates from pasted tsv with Japanese column labels' do
      song = create_song(title: 'Controller Japanese TSV Song')
      original_song = create_original_song(title: 'Controller Japanese TSV Original')
      tsv = [
        KaraokeSongTsvColumns.labels(KaraokeSongBulkEditor::COLUMNS).join("\t"),
        [
          song.id,
          song.karaoke_type,
          song.display_artist.name,
          song.title,
          original_song.title,
          'https://youtube.example/japanese-header',
          '',
          '',
          '',
          '',
          ''
        ].join("\t")
      ].join("\n")

      post admin_karaoke_song_bulk_edit_path, params: { bulk_tsv: tsv }

      assert_redirected_to admin_karaoke_song_bulk_edit_path(status: 'missing')
      assert_equal [original_song], song.reload.original_songs.to_a
      assert_equal 'https://youtube.example/japanese-header', song.youtube_url
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

    private

    def with_cache_store(store)
      original_cache = Rails.cache
      Rails.cache = store
      yield
    ensure
      store.clear
      Rails.cache = original_cache
    end
  end
end
