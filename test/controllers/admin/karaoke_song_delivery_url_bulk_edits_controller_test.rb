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
        assert_select 'th[title=?]', column, text: KaraokeSongTsvColumns.label(column)
      end
      assert_select 'textarea[name="bulk_tsv"]' do |elements|
        assert_equal KaraokeSongTsvColumns.labels(KaraokeSongDeliveryUrlBulkEditor::COLUMNS).join("\t"), elements.first['placeholder']
        assert_equal '配信URL TSV', elements.first['aria-label']
        assert_equal 'admin-delivery-url-bulk-tsv-help', elements.first['aria-describedby']
      end
      assert_select '#admin-delivery-url-bulk-tsv-help', text: 'TSVのヘッダー行とデータ行を貼り付けると、表示中の配信URL入力欄へ反映できます。'
      assert_select "input[name=?]", "songs[#{linked_song.id}][youtube_url]"
      assert_select "input[name=?]", "songs[#{linked_song.id}][line_music_url]"
      assert_select "input[name=?][placeholder=?]", "songs[#{linked_song.id}][youtube_url]", 'https://www.youtube.com/watch?v=...'
      assert_select "input[name=?][placeholder=?]", "songs[#{linked_song.id}][line_music_url]", 'https://music.line.me/webapp/track/...'
      assert_select "input[name=?][aria-label=?]", "songs[#{linked_song.id}][youtube_url]", "#{linked_song.title}のYouTube URL"
      assert_select "input[name=?][aria-label=?]", "songs[#{linked_song.id}][line_music_url]", "#{linked_song.title}のLINE MUSIC URL"
      assert_select 'button.admin-copy-button[data-admin-copy-text=?][aria-label=?]', linked_song.display_artist.name, "#{linked_song.display_artist.name}をコピー"
      assert_select 'a[data-admin-copy-text]', count: 0
      assert_select 'a[href=?]', admin_song_path(linked_song), text: linked_song.title
      assert_select 'form[data-admin-filter-form]'
      assert_select '.admin-search-field .admin-sr-only', text: 'キーワード'
      assert_select 'input[type="search"][name="q"][aria-label="カラオケ配信URL編集をキーワード検索"]'
      assert_select '.admin-bulk-apply-warning.alert.alert-warning', text: '反映は配信URLを更新するため、先に変更チェックで内容を確認してください。'
      assert_select '#admin-delivery-url-bulk-update-note', text: '反映は配信URLを更新するため、先に変更チェックで内容を確認してください。'
      assert_select 'button[aria-label="配信URL変更チェックを実行"][name="mode"][value="preview"]'
      assert_select 'button.btn-warning[data-turbo-confirm=?]', '配信URLの変更をDBに反映します。変更チェック結果を確認済みですか？'
      assert_select 'button[aria-label="配信URL変更をDBに反映"][aria-describedby="admin-delivery-url-bulk-update-note"][name="mode"][value="update"][disabled]'
      assert_select '.admin-delivery-url-control-group h2', text: '絞り込み'
      assert_select '.admin-delivery-url-control-group h2', text: '並び替え'
      assert_select 'input[name="missing_url_columns[]"][value="youtube_url"][data-admin-auto-submit]'
      missing_url_column_ids = css_select('input[name="missing_url_columns[]"]').filter_map { |element| element['id'] }
      assert_equal missing_url_column_ids.uniq, missing_url_column_ids
      assert_select 'select[name="karaoke_type"][aria-label="配信種別"][data-admin-auto-submit]'
      assert_select 'select[name="sort"][aria-label="並び替え項目"][data-admin-auto-submit] option[selected][value="created_at"]'
      assert_select 'select[name="direction"][aria-label="並び順"][data-admin-auto-submit] option[selected][value="desc"]'
      assert_select 'select[name="per_page"][aria-label="1ページの表示件数"][data-admin-auto-submit] option[selected][value="25"]'
      assert_select 'select[name="per_page"] option[value="25"]'
      assert_select 'select[name="per_page"] option[value="50"]'
      assert_select 'select[name="per_page"] option[value="100"]'
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
      assert_select 'label.admin-url-filter-option-active', text: /YouTube URL 設定済みを非表示/

      get admin_karaoke_song_delivery_url_bulk_edit_path, params: { missing_url_columns: %w[youtube_url spotify_url] }

      assert_response :success
      assert_includes response.body, missing_youtube_song.title
      assert_not_includes response.body, filled_youtube_song.title
      assert_not_includes response.body, filled_spotify_song.title
      assert_select 'input[name="missing_url_columns[]"][value="youtube_url"][checked]'
      assert_select 'input[name="missing_url_columns[]"][value="spotify_url"][checked]'
      assert_select 'label.admin-url-filter-option-active', count: 2
    end

    test 'shows empty state when no songs match filters' do
      get admin_karaoke_song_delivery_url_bulk_edit_path, params: { q: '一致しないURL編集検索語' }

      assert_response :success
      assert_select 'tbody tr', 0
      assert_select '.admin-empty-state.alert[role="status"] p', text: '条件に一致する楽曲がありません'
      assert_select '.admin-empty-state.alert a[href=?]', admin_karaoke_song_delivery_url_bulk_edit_path, text: /条件をクリア/
    end

    test 'labels pagination navigation' do
      artist = create_display_artist(name: 'Delivery Pagination Artist')
      101.times { |index| create_song(display_artist: artist, title: "Delivery Pagination Song #{index}") }

      get admin_karaoke_song_delivery_url_bulk_edit_path, params: { per_page: 50 }

      assert_response :success
      assert_select '.admin-pagination[aria-label="カラオケ配信URL編集のページ移動"] span[aria-current="page"]', text: %r{1 / \d+}
      assert_select 'select[name="per_page"] option[selected][value="50"]'
      assert_select '.admin-result-summary', text: %r{表示中\s+50\s+/ .* 件}
      assert_select 'a[href*="per_page=50"]', text: /次へ/
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

      post admin_karaoke_song_delivery_url_bulk_edit_path(missing_url_columns: ['youtube_url'], per_page: 50), params: {
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

      assert_redirected_to admin_karaoke_song_delivery_url_bulk_edit_path(missing_url_columns: ['youtube_url'], per_page: 50)
      follow_redirect!
      assert_select '.admin-flash-notice', text: '更新が完了しました。更新件数: 1件、変更なし: 0件'
      assert_equal [original_song], song.reload.original_songs.to_a
      assert_equal 'https://youtube.example/controller', song.youtube_url
      assert_equal 'https://open.spotify.example/controller', song.spotify_url
      assert_equal 'https://music.line.example/controller', song.line_music_url
    end

    test 'delivery url bulk updates invalidate dashboard counts' do
      song = create_song(title: 'Controller Delivery Cache Song')

      with_cache_store(ActiveSupport::Cache::MemoryStore.new) do
        Rails.cache.write(DashboardCache::KEY, { total_songs: 1 })
        post admin_karaoke_song_delivery_url_bulk_edit_path, params: {
          songs: { song.id => { youtube_url: 'https://youtube.example/cache' } }
        }

        assert_redirected_to admin_karaoke_song_delivery_url_bulk_edit_path
        assert_not Rails.cache.exist?(DashboardCache::KEY)
      end
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
      assert_select '.admin-delivery-url-preview-row li span', text: /YouTube URL/
      assert_select '.admin-delivery-url-preview-row strong', text: %r{https://youtube.example/preview}
      assert_select '#admin-delivery-url-bulk-update-note', text: '変更チェック結果を確認済みです。反映すると表示中の配信URLでDBを更新します。'
      assert_select 'button[aria-label="配信URL変更をDBに反映"][name="mode"][value="update"][disabled]', false
      assert_equal '', song.reload.youtube_url
    end

    test 'preview shows submitted youtube url instead of existing db value' do
      song = create_song(title: 'Controller Delivery URL Preview Submitted Song', youtube_url: 'https://youtube.example/existing-db-value')

      post admin_karaoke_song_delivery_url_bulk_edit_path, params: {
        mode: 'preview',
        songs: {
          song.id => {
            youtube_url: 'https://youtube.example/preview-submitted',
            nicovideo_url: '',
            apple_music_url: '',
            youtube_music_url: '',
            spotify_url: '',
            line_music_url: ''
          }
        }
      }

      assert_response :success
      assert_select 'input[name=?][value=?]', "songs[#{song.id}][youtube_url]", 'https://youtube.example/preview-submitted'
      assert_equal 'https://youtube.example/existing-db-value', song.reload.youtube_url
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

    test 'updates from pasted delivery url tsv with Japanese column labels' do
      song = create_song(title: 'Controller Delivery URL Japanese TSV Song')
      tsv = [
        KaraokeSongTsvColumns.labels(KaraokeSongDeliveryUrlBulkEditor::COLUMNS).join("\t"),
        [
          song.id,
          song.karaoke_type,
          song.display_artist.name,
          song.title,
          '',
          'https://youtube.example/japanese-header',
          '',
          '',
          '',
          '',
          ''
        ].join("\t")
      ].join("\n")

      post admin_karaoke_song_delivery_url_bulk_edit_path, params: { bulk_tsv: tsv }

      assert_redirected_to admin_karaoke_song_delivery_url_bulk_edit_path
      assert_equal 'https://youtube.example/japanese-header', song.reload.youtube_url
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
