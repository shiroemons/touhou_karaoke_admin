require 'test_helper'
require 'securerandom'

module Admin
  class ResourcesControllerTest < ActionDispatch::IntegrationTest
    include ResourcePathHelper

    setup do
      @original = Original.create!(code: '0001', title: '東方紅魔郷', short_title: '紅', original_type: 'windows', series_order: 6.0)
      @original_song = OriginalSong.create!(code: '000101', original: @original, title: '赤より紅い夢', composer: 'ZUN', track_number: 1)
      @circle = Circle.create!(name: '上海アリス幻樂団')
      @display_artist = DisplayArtist.create!(karaoke_type: 'DAM', name: 'ZUN', name_reading: 'ずん', url: 'https://example.com/artists/zun')
      @circle.display_artists << @display_artist
      @dam_song = DamSong.create!(display_artist: @display_artist, title: 'DAM Song', url: 'https://example.com/dam/song')
      @song = Song.create!(display_artist: @display_artist, karaoke_type: 'DAM', title: 'Karaoke Song', url: 'https://example.com/song')
      @song.original_songs << @original_song
      @delivery_model = KaraokeDeliveryModel.create!(name: 'LIVE DAM AiR', karaoke_type: 'DAM', order: 100)
      @song.karaoke_delivery_models << @delivery_model
      @joysound_song = JoysoundSong.create!(display_title: 'JOYSOUND Song', url: 'https://example.com/joysound/song')
      @joysound_music_post = JoysoundMusicPost.create!(
        title: 'Music Post Song',
        artist: 'ZUN',
        producer: 'producer',
        delivery_deadline_on: Date.current,
        url: 'https://example.com/music-post/song'
      )
      @dam_artist_url = DamArtistUrl.create!(url: 'https://example.com/dam/artist')
      @dam_ouchikaraoke = SongWithDamOuchikaraoke.create!(song: @song, url: 'https://example.com/ouchikaraoke')
      @joysound_utasuki = SongWithJoysoundUtasuki.create!(song: @song, delivery_deadline_date: Date.current, url: 'https://example.com/utasuki')
    end

    test 'dashboard renders navigation to admin resources' do
      get admin_root_path

      assert_response :success
      assert_select '.admin-dashboard-hero h1', text: '管理画面'
      assert_select '.admin-dashboard-feature-card', text: /カラオケ配信曲/
      assert_select '.admin-dashboard-status-list', text: /原曲紐付け済み/
      assert_select '.admin-dashboard-bar-group h3', text: '配信種別'
      assert_select '.admin-dashboard-bar-group h3', text: '動画'
      assert_select '.admin-dashboard-bar-group h3', text: '音楽配信'
      assert_select '.admin-dashboard-bar-row', text: /DAM/
      assert_select '.admin-dashboard-bar-row', text: /ニコニコ動画/
      assert_select '.admin-dashboard-bar-row', text: /YouTube Music/
      assert_select '.admin-dashboard-bar-row', text: /Spotify/
      assert_select '.admin-dashboard-bar-row', text: /LINE MUSIC/
      assert_select '.admin-dashboard-action-link', text: 'DAM楽曲を取得'
      assert_select '.admin-dashboard-insight-group h3', text: 'データ状態'
      assert_select '.admin-dashboard-insight-group h3', text: 'マスタデータ'
      assert_select '.admin-dashboard-insight-group h3', text: 'ミュージックポスト'
      assert_select '.admin-insight-card span', text: '原曲未紐付け'
      assert_select '.admin-insight-card span', text: '期限切れ'
      assert_select '.admin-dashboard-management-panel h3', text: '配信管理'
      assert_select '.admin-dashboard-management-primary', text: /まず見る/
      assert_select '.admin-dashboard-management-primary', text: /カラオケ配信曲/
      assert_select 'a.admin-dashboard-management-link', text: /原曲/
    end

    test 'all resources render index and show pages' do
      resource_records.each do |resource, record|
        get admin_resources_path(resource)

        assert_response :success, "#{resource.key} index should render"
        assert_select 'tbody tr td:not(.admin-actions-column)', { minimum: 1 }, "#{resource.key} index should render data cells"

        get admin_resource_path(resource, record)

        assert_response :success, "#{resource.key} show should render"
      end
    end

    test 'show page renders title labels identifiers and badge fields' do
      get admin_song_path(@song)

      assert_response :success
      assert_select 'h1', text: '[DAM] Karaoke Song'
      assert_select '.admin-detail-identity code', text: @song.id.to_s

      get admin_original_path(@original)

      assert_response :success
      assert_select '.admin-detail-identity code', text: @original.code
      assert_select '.admin-badge', text: 'windows'

      get admin_original_song_path(@original_song)

      assert_response :success
      assert_select 'h1', text: '[紅] 赤より紅い夢'
      assert_select '.admin-detail-identity code', text: @original_song.code
    end

    test 'search filters index by allowed columns' do
      Circle.create!(name: '検索対象外')

      get admin_circles_path, params: { q: '上海' }

      assert_response :success
      assert_select 'td', text: '上海アリス幻樂団'
      assert_select 'td', { text: '検索対象外', count: 0 }
    end

    test 'filters index independently from keyword search' do
      DisplayArtist.create!(karaoke_type: 'JOYSOUND', name: 'JOYSOUND Artist', url: 'https://example.com/joysound-artist')

      get admin_display_artists_path, params: { filters: { karaoke_type: 'dam' } }

      assert_response :success
      assert_select 'td', text: 'ZUN'
      assert_select 'td', { text: 'JOYSOUND Artist', count: 0 }
      assert_select 'input[name="filters[karaoke_type]"][value="dam"][checked="checked"]'
    end

    test 'ignores undefined filter values safely' do
      DisplayArtist.create!(karaoke_type: 'JOYSOUND', name: 'JOYSOUND Artist', url: 'https://example.com/joysound-artist')

      get admin_display_artists_path, params: { filters: { karaoke_type: 'invalid' } }

      assert_response :success
      assert_select 'td', text: 'ZUN'
      assert_select 'td', text: 'JOYSOUND Artist'
    end

    test 'searches songs by display artist name' do
      other_artist = DisplayArtist.create!(
        karaoke_type: 'DAM',
        name: 'Search Target Artist',
        url: 'https://example.com/search-target-artist'
      )
      target_song = Song.create!(
        display_artist: other_artist,
        karaoke_type: 'DAM',
        title: 'Artist Search Song',
        url: 'https://example.com/artist-search-song'
      )

      get admin_songs_path, params: { q: other_artist.name }

      assert_response :success
      assert_select 'td', text: target_song.title
      assert_select 'td', { text: @song.title, count: 0 }
    end

    test 'filters songs by original link status' do
      missing_song = Song.create!(display_artist: @display_artist, karaoke_type: 'DAM', title: 'Missing Original Song', url: 'https://example.com/missing')

      get admin_songs_path, params: { filters: { original_link: 'missing' } }

      assert_response :success
      assert_select 'td', text: missing_song.title
      assert_select 'td', { text: @song.title, count: 0 }

      get admin_songs_path, params: { filters: { original_link: 'linked' } }

      assert_response :success
      assert_select 'td', text: @song.title
      assert_select 'td', { text: missing_song.title, count: 0 }
    end

    test 'filters songs by original song category' do
      original_song = OriginalSong.create!(code: '000198', original: @original, title: 'オリジナル', composer: 'ZUN', track_number: 98)
      original_category_song = Song.create!(
        display_artist: @display_artist,
        karaoke_type: 'DAM',
        title: 'Original Filter Song',
        url: 'https://example.com/original-filter'
      )
      original_category_song.original_songs << original_song
      missing_song = Song.create!(
        display_artist: @display_artist,
        karaoke_type: 'DAM',
        title: 'Missing Filter Song',
        url: 'https://example.com/missing-filter'
      )

      get admin_songs_path, params: { filters: { original_category: 'touhou_arrange' } }

      assert_response :success
      assert_select 'td', text: @song.title
      assert_select 'td', { text: original_category_song.title, count: 0 }
      assert_select 'td', { text: missing_song.title, count: 0 }

      get admin_songs_path, params: { filters: { original_category: 'original_or_other' } }

      assert_response :success
      assert_select 'td', text: original_category_song.title
      assert_select 'td', { text: @song.title, count: 0 }
      assert_select 'td', { text: missing_song.title, count: 0 }

      get admin_songs_path, params: { filters: { original_category: 'missing' } }

      assert_response :success
      assert_select 'td', text: missing_song.title
      assert_select 'td', { text: @song.title, count: 0 }
      assert_select 'td', { text: original_category_song.title, count: 0 }
    end

    test 'song index shows service status columns in information order' do
      @song.update!(
        youtube_url: 'https://youtube.example/watch',
        apple_music_url: 'https://music.apple.example/song',
        spotify_url: 'https://spotify.example/track'
      )

      get admin_songs_path, params: { q: @song.title }

      assert_response :success
      assert_select 'table.admin-table-resource-song'
      assert_select 'thead th:nth-child(2)', text: 'カラオケ種別'
      assert_select 'thead th.admin-table-field-karaoke-type'
      assert_select 'thead th:nth-child(3)', text: 'タイトル'
      assert_select 'thead th.admin-table-field-title'
      assert_select 'thead th:nth-child(4)', text: 'アーティスト'
      assert_select 'thead th.admin-table-field-display-artist'
      assert_select 'thead th:nth-child(5)', text: '原曲紐付け'
      assert_select 'thead th.admin-table-field-original-songs-link-status'
      assert_select 'thead th:nth-child(6)', text: '原曲数'
      assert_select 'thead th.admin-table-field-original-songs-count-label'
      assert_select 'thead th:nth-child(7)', text: '分類'
      assert_select 'thead th.admin-table-field-original-song-category-label'
      assert_select 'thead th:nth-child(8)', text: '動画'
      assert_select 'thead th:nth-child(9)', text: '音楽配信'
      assert_select 'thead th', text: '更新日時'
      formatted_updated_at = @song.updated_at.in_time_zone('Asia/Tokyo').strftime('%Y/%m/%d %H:%M')
      assert_select 'td', text: /#{Regexp.escape(formatted_updated_at)}/
      assert_select '.admin-badge', text: 'あり'
      assert_select 'td', text: '1曲'
      assert_select '.admin-badge', text: '東方アレンジ'
      assert_select '.admin-service-badge-active', text: 'YouTube'
      assert_select '.admin-service-badge-active', text: 'Apple'
      assert_select '.admin-service-badge-active', text: 'Spotify'
      assert_select 'th', { text: 'touhou', count: 0 }
    end

    test 'song index shows original song status for missing and original other songs' do
      original_song = OriginalSong.create!(code: '000199', original: @original, title: 'オリジナル', composer: 'ZUN', track_number: 99)
      original_category_song = Song.create!(display_artist: @display_artist, karaoke_type: 'DAM', title: 'Original Category Song', url: 'https://example.com/original-category')
      original_category_song.original_songs << original_song
      missing_song = Song.create!(display_artist: @display_artist, karaoke_type: 'DAM', title: 'Missing Category Song', url: 'https://example.com/missing-category')

      get admin_songs_path, params: { q: 'Category Song' }

      assert_response :success
      assert_select 'td', text: original_category_song.title
      assert_select 'td', text: missing_song.title
      assert_select '.admin-badge', text: 'オリジナル・その他'
      assert_select '.admin-badge', text: '未紐付け'
      assert_select '.admin-badge', text: 'なし'
      assert_select 'td', text: '0曲'
    end

    test 'sorts index by updated at column' do
      older_circle = Circle.create!(name: 'Updated Sort Old')
      newer_circle = Circle.create!(name: 'Updated Sort New')
      older_circle.update!(updated_at: 2.days.ago)
      newer_circle.update!(updated_at: 1.hour.ago)

      get admin_circles_path, params: { q: 'Updated Sort', sort: 'updated_at', direction: 'desc' }

      assert_response :success
      assert_select 'thead th', text: '更新日時'
      assert_select 'tbody tr:first-child td', text: newer_circle.name
      assert_select 'tbody tr:first-child.admin-row-updated'
      assert_select 'tbody tr:first-child .admin-update-badge-update', text: '更新'
      assert_select 'a.admin-sort-link-active .admin-sort-label', text: '更新日時'
    end

    test 'marks recently created resources in index' do
      Circle.create!(name: 'Recently Created Marker')

      get admin_circles_path, params: { q: 'Recently Created Marker' }

      assert_response :success
      assert_select 'tbody tr.admin-row-created'
      assert_select '.admin-update-badge-create', text: '追加'
    end

    test 'filters songs by video and music service presence' do
      service_song = Song.create!(
        display_artist: @display_artist,
        karaoke_type: 'DAM',
        title: 'Service Linked Song',
        url: 'https://example.com/service-linked',
        nicovideo_url: 'https://nicovideo.example/watch',
        spotify_url: 'https://spotify.example/track'
      )

      get admin_songs_path, params: { filters: { video_service: { nicovideo: 'present' }, music_service: { spotify: 'present' } } }

      assert_response :success
      assert_select 'td', text: service_song.title
      assert_select 'td', { text: @song.title, count: 0 }
      assert_select 'input[name="filters[video_service][nicovideo]"][value="present"][checked="checked"]'
      assert_select 'input[name="filters[music_service][spotify]"][value="present"][checked="checked"]'

      get admin_songs_path, params: { filters: { video_service: { youtube: 'missing' }, music_service: { spotify: 'missing' } } }

      assert_response :success
      assert_select 'td', text: @song.title
      assert_select 'td', { text: service_song.title, count: 0 }
    end

    test 'chooses filter controls by option count and combinability' do
      get admin_songs_path

      assert_response :success
      assert_select 'input[type="radio"][name="filters[karaoke_type]"]'
      assert_select 'input[type="radio"][name="filters[original_link]"][value="linked"]'
      assert_select 'input[type="radio"][name="filters[original_link]"][value="missing"]'
      assert_select 'input[type="radio"][name="filters[original_category]"][value="touhou_arrange"]'
      assert_select 'input[type="radio"][name="filters[original_category]"][value="original_or_other"]'
      assert_select 'input[type="radio"][name="filters[original_category]"][value="missing"]'
      assert_select 'input[type="radio"][name="filters[video_service][youtube]"][value="present"]'
      assert_select 'input[type="radio"][name="filters[video_service][youtube]"][value="missing"]'
      assert_select 'input[type="radio"][name="filters[music_service][spotify]"][value="present"]'
      assert_select 'input[type="radio"][name="filters[music_service][spotify]"][value="missing"]'

      get admin_original_songs_path

      assert_response :success
      assert_select 'select[name="filters[original_type]"]'
    end

    test 'filters original resources by enum values' do
      Original.create!(code: '0002', title: '旧作', short_title: '旧', original_type: 'pc98', series_order: 1.0)

      get admin_originals_path, params: { filters: { original_type: 'windows' } }

      assert_response :success
      assert_select 'td', text: '東方紅魔郷'
      assert_select 'td', { text: '旧作', count: 0 }
    end

    test 'sorts index by sortable columns and cycles back to default' do
      Circle.create!(name: 'Sort Circle B')
      Circle.create!(name: 'Sort Circle A')

      get admin_circles_path, params: { q: 'Sort Circle', sort: 'name', direction: 'asc' }

      assert_response :success
      assert_select 'tbody tr:first-child td', text: 'Sort Circle A'
      assert_select 'a.admin-sort-link-active .admin-sort-label', text: 'サークル名'

      get admin_circles_path, params: { q: 'Sort Circle', sort: 'name', direction: 'desc' }

      assert_response :success
      assert_select 'tbody tr:first-child td', text: 'Sort Circle B'
      assert_select 'a.admin-sort-link-active' do |links|
        href = links.first['href']
        assert_includes href, 'q=Sort+Circle'
        assert_not_includes href, 'sort='
        assert_not_includes href, 'direction='
      end
    end

    test 'sorts index by displayed count columns' do
      empty_circle = Circle.create!(name: 'Count Sort Empty')
      many_circle = Circle.create!(name: 'Count Sort Many')
      artist_one = DisplayArtist.create!(karaoke_type: 'DAM', name: 'Count Sort Artist 1', url: 'https://example.com/count-sort-1')
      artist_two = DisplayArtist.create!(karaoke_type: 'DAM', name: 'Count Sort Artist 2', url: 'https://example.com/count-sort-2')
      many_circle.display_artists << [artist_one, artist_two]
      Song.create!(display_artist: artist_one, karaoke_type: 'DAM', title: 'Count Sort Song', url: 'https://example.com/count-sort-song')

      get admin_circles_path, params: { q: 'Count Sort', sort: 'display_artists_count', direction: 'desc' }

      assert_response :success
      assert_select 'tbody tr:first-child td', text: many_circle.name
      assert_select 'tbody tr:last-child td', text: empty_circle.name
      assert_select 'a.admin-sort-link-active .admin-sort-label', text: 'アーティスト数'

      get admin_circles_path, params: { q: 'Count Sort', sort: 'songs_count', direction: 'desc' }

      assert_response :success
      assert_select 'tbody tr:first-child td', text: many_circle.name
      assert_select 'tbody tr:last-child td', text: empty_circle.name
      assert_select 'a.admin-sort-link-active .admin-sort-label', text: '曲数'
    end

    test 'filters delivery models by karaoke type' do
      joysound_model_name = "JOYSOUND MAX #{SecureRandom.hex(4)}"
      KaraokeDeliveryModel.create!(name: joysound_model_name, karaoke_type: 'JOYSOUND', order: 101)

      get admin_karaoke_delivery_models_path, params: { filters: { karaoke_type: 'DAM' } }

      assert_response :success
      assert_select 'td', text: 'LIVE DAM AiR'
      assert_select 'td', { text: joysound_model_name, count: 0 }
    end

    test 'filters joysound songs by service flags' do
      disabled_song = JoysoundSong.create!(display_title: 'Disabled JOYSOUND Song', url: 'https://example.com/joysound/disabled')
      enabled_song = JoysoundSong.create!(
        display_title: 'Smartphone JOYSOUND Song',
        url: 'https://example.com/joysound/smartphone',
        smartphone_service_enabled: true
      )

      get admin_joysound_songs_path, params: { filters: { service_enabled: 'smartphone' } }

      assert_response :success
      assert_select 'td', text: enabled_song.display_title
      assert_select 'td', { text: disabled_song.display_title, count: 0 }
    end

    test 'filters music posts by joysound url presence' do
      linked_post = JoysoundMusicPost.create!(
        title: 'Linked Music Post',
        artist: 'ZUN',
        producer: 'producer',
        delivery_deadline_on: Date.current,
        url: 'https://example.com/music-post/linked',
        joysound_url: 'https://example.com/joysound/linked'
      )

      get admin_joysound_music_posts_path, params: { filters: { joysound_url: 'present' } }

      assert_response :success
      assert_select 'td', text: linked_post.title
      assert_select 'td', { text: @joysound_music_post.title, count: 0 }
    end

    test 'pagination limits index records' do
      30.times { |index| Circle.create!(name: "Circle #{index}") }

      get admin_circles_path, params: { per_page: 24, view_mode: 'paginated' }

      assert_response :success
      assert_select 'tbody tr', 24
      assert_select '.admin-pagination', text: %r{1 / 2}
    end

    test 'index links operations to dedicated action pages' do
      get admin_songs_path

      assert_response :success
      assert_select 'form.admin-inline-operation', false
      assert_select '.admin-operation-dropdown-wrap'
      assert_select 'th.admin-select-column'
      assert_select 'input[data-admin-resource-select]', 1
      assert_select 'dialog[data-admin-operation-modal]'
      assert_select '[data-admin-operation-panel="export_songs"]'
      assert_select '[data-admin-operation-panel="export_songs"] form[data-admin-operation-form][data-admin-operation-inline-confirmation="true"][data-admin-operation-selection-required="true"]'
      assert_select '[data-admin-operation-panel="export_songs"] [data-admin-operation-selected-ids]'
      assert_select '[data-admin-operation-panel="export_songs"] [data-admin-operation-selection-note]', text: '対象を選択してください。'
      assert_select '[data-admin-operation-panel="export_songs"] button[data-admin-operation-submit][disabled]'
      assert_select '.admin-operation-dropdown-group h3', text: 'TSV入出力'
      assert_select '.admin-operation-dropdown-group h3', text: '外部取得'
      assert_select '.admin-display-settings .admin-operation-dropdown-wrap', false
      assert_select '.admin-table-controls .admin-table-display-settings'
      assert_select 'a.admin-operation-dropdown-item[href=?][data-admin-operation-trigger][data-admin-operation-key="export_songs"]', operation_admin_songs_path(operation: 'export_songs'), text: '楽曲TSVをエクスポート'
    end

    test 'all operations have explicit descriptions' do
      ResourceRegistry.all.each_value do |resource|
        resource.operations.each do |operation|
          assert operation.description.present?, "#{resource.key} #{operation.key} should have a description"
          assert_not_equal operation.confirmation, operation.description, "#{resource.key} #{operation.key} should not reuse confirmation as description" if operation.confirmation.present?
        end
      end
    end

    test 'filters are collapsible and open when active' do
      get admin_songs_path

      assert_response :success
      assert_select 'details.admin-filter-disclosure'
      assert_select 'details.admin-filter-disclosure[open]', false

      get admin_songs_path, params: { filters: { karaoke_type: 'dam' } }

      assert_response :success
      assert_select 'details.admin-filter-disclosure[open]'
      assert_select '.admin-filter-active-count', text: '1件指定中'
    end

    test 'index uses infinite scroll by default' do
      30.times { |index| Circle.create!(name: "Infinite Circle #{index}") }

      get admin_circles_path, params: { per_page: 24 }

      assert_response :success
      assert_select 'tbody tr', 24
      assert_select '.admin-pagination', false
      assert_select '.admin-table-wrap .admin-infinite-scroll[data-next-url]'
      assert_select 'a.admin-view-mode-button-active', text: '無限スクロール'
    end

    test 'infinite scroll rows endpoint returns next page html and next url' do
      30.times { |index| Circle.create!(name: "Infinite Row #{index}") }

      get admin_circles_path, params: { per_page: 24, page: 2, view_mode: 'infinite', partial: 'rows' }

      assert_response :success
      assert_equal 'application/json', response.media_type
      payload = response.parsed_body
      assert_includes payload['html'], '<tr class='
      assert_nil payload['next_url']
    end

    test 'async index endpoint returns replaceable admin resource content' do
      get admin_circles_path, params: { partial: 'content', sort: 'display_artists_count', direction: 'asc' }

      assert_response :success
      assert_equal 'application/json', response.media_type
      payload = response.parsed_body
      assert_includes payload['html'], 'data-admin-resource-content'
      assert_includes payload['html'], 'アーティスト数'
      assert_not_includes payload['html'], '<aside class="admin-sidebar"'
    end

    test 'creates writable resource' do
      assert_difference -> { Circle.count }, 1 do
        post admin_circles_path, params: { circle: { name: '新規サークル' } }
      end

      assert_redirected_to admin_circle_path(Circle.order(:created_at).last)
      assert_equal 'create', Admin::ChangeLog.last.event
      assert_equal 'サークル', Admin::ChangeLog.last.resource_label
    end

    test 'returns to form on validation error' do
      assert_no_difference -> { KaraokeDeliveryModel.count } do
        post admin_karaoke_delivery_models_path, params: { karaoke_delivery_model: { name: '', karaoke_type: 'DAM', order: 200 } }
      end

      assert_response :unprocessable_content
      assert_select '.admin-errors'
    end

    test 'renders edit form for writable resource' do
      get edit_admin_song_path(@song)

      assert_response :success
      assert_select 'form'
      assert_select 'input[name="song[youtube_url]"]'
    end

    test 'updates resource through strong parameters' do
      patch admin_song_path(@song), params: {
        song: {
          title: 'Ignored Title',
          youtube_url: 'https://youtube.com/watch?v=example'
        }
      }

      assert_redirected_to admin_song_path(@song)
      @song.reload
      assert_equal 'Karaoke Song', @song.title
      assert_equal 'https://youtube.com/watch?v=example', @song.youtube_url
      assert_equal 'update', Admin::ChangeLog.last.event
      assert_equal 'YouTube URL', Admin::ChangeLog.last.changed_fields.fetch('youtube_url').fetch('label')

      follow_redirect!
      assert_select '.admin-change-event-update', text: '更新'
      assert_select '.admin-change-field dt', text: 'YouTube URL'
    end

    test 'destroys resource when policy allows it' do
      artist = DisplayArtist.create!(karaoke_type: 'DAM', name: 'No Songs', url: 'https://example.com/no-songs')

      assert_difference -> { DisplayArtist.count }, -1 do
        delete admin_display_artist_path(artist)
      end

      assert_redirected_to admin_display_artists_path
    end

    test 'denies access when policy does not allow the action' do
      get new_admin_original_path

      assert_redirected_to admin_root_path
      follow_redirect!
      assert_select '.admin-flash-alert', text: 'この操作を実行する権限がありません。'
    end

    test 'renders collection action page with description dialog and progress' do
      get operation_admin_dam_songs_path(operation: 'fetch_dam_song')

      assert_response :success
      assert_select 'h1', text: 'DAM楽曲を取得'
      assert_select '.admin-operation-description', text: /入力されたDAM楽曲URLから/
      assert_select '.admin-operation-description a[href=?]', Constants::Karaoke::Dam::SONG_URL, text: Constants::Karaoke::Dam::SONG_URL
      assert_select 'form[data-admin-operation-form][data-admin-operation-action="FetchDamSong"]'
      assert_select 'form[data-admin-operation-form][data-admin-operation-progress-url]'
      assert_select 'input[name="operation_fields[dam_song_url]"]'
      assert_select 'input[name="operation_progress_id"]', 1
      assert_select 'dialog[data-admin-operation-dialog]'
      assert_select '[data-admin-operation-progress]'
      assert_select '[data-admin-operation-progressbar][aria-valuemin="0"][aria-valuemax="100"][aria-valuenow="0"]'
      assert_select '[data-admin-operation-progress-percent]', text: '0%'
      assert_select '[data-admin-operation-progress-elapsed]', text: '00:00'
      assert_select '[data-admin-operation-progress-status]', text: '待機中'
      assert_select '.admin-operation-progress-kicker', text: '処理進捗'
      assert_select '.admin-operation-progress-step', text: '入力内容を確認'
      assert_select '.admin-operation-progress-step', text: '外部サイト取得・保存'
      assert_select '.admin-operation-progress-step', text: '結果を反映'
    end

    test 'renders estimated progress metadata for external fetch action' do
      get operation_admin_dam_songs_path(operation: 'fetch_dam_touhou_songs')

      assert_response :success
      assert_select 'h1', text: '東方DAM楽曲を取得'
      assert_select 'form[data-admin-operation-form][data-admin-operation-estimated-seconds="40"]'
      assert_select 'form[data-admin-operation-form][data-admin-operation-async="true"]'
    end

    test 'renders full joysound music post maintenance steps in operation description' do
      get operation_admin_joysound_music_posts_path(operation: 'perform_full_joysound_music_post_maintenance')

      assert_response :success
      assert_select 'h1', text: 'フルメンテナンス'
      assert_select '.admin-operation-description', text: /期限切れクリーンアップ/
      assert_select '.admin-operation-description', text: /楽曲取得/
      assert_select '.admin-operation-description', text: /URL確認/
      assert_select '.admin-operation-description', text: /配信期限更新/
      assert_select '.admin-operation-description', text: /削除・更新を伴います/
      assert_select '.admin-operation-description a[href=?]', Constants::Karaoke::Joysound::SEARCH_URL
      assert_select '.admin-operation-description a[href=?]', Constants::Karaoke::Joysound::MUSIC_POST_BASE_URL
    end

    test 'operation progress endpoint returns current progress payload' do
      progress_id = SecureRandom.uuid
      OperationProgress.update!(
        progress_id,
        state: 'running',
        percentage: 42,
        status: '外部サイト取得中',
        label: 'DAM検索結果 2/? ページ目を保存しています',
        detail: '処理済み: 120件',
        current: 120
      )

      get operation_progress_admin_dam_songs_path(operation: 'fetch_dam_touhou_songs', operation_progress_id: progress_id)

      assert_response :success
      payload = response.parsed_body
      assert_equal 'running', payload['state']
      assert_equal 42, payload['percentage']
      assert_equal '外部サイト取得中', payload['status']
      assert_equal '処理済み: 120件', payload['detail']
      assert_equal 120, payload['current']
    end

    test 'method operation receives progress callback and completes progress' do
      progress_id = SecureRandom.uuid
      fetch = lambda do |progress: nil|
        progress.call(percentage: 55, status: '外部サイト取得中', label: 'DAM検索結果を保存しています')
      end

      original_fetch = DamSong.method(:fetch_dam_touhou_songs)
      DamSong.define_singleton_method(:fetch_dam_touhou_songs, &fetch)
      begin
        perform_enqueued_jobs do
          post operation_admin_dam_songs_path, params: { operation: 'fetch_dam_touhou_songs', operation_progress_id: progress_id }
        end
      ensure
        DamSong.define_singleton_method(:fetch_dam_touhou_songs, &original_fetch)
      end

      assert_redirected_to admin_dam_songs_path
      progress = OperationProgress.read(progress_id)
      assert_equal 'completed', progress[:state]
      assert_equal 100, progress[:percentage]
    end

    test 'async operation json request enqueues operation job and returns queued progress' do
      progress_id = SecureRandom.uuid

      assert_enqueued_with(job: OperationJob, queue: 'admin_operations') do
        post operation_admin_dam_songs_path(format: :json), params: {
          operation: 'fetch_dam_touhou_songs',
          operation_progress_id: progress_id
        }
      end

      assert_response :accepted
      payload = response.parsed_body
      assert_equal '東方DAM楽曲を取得のバックグラウンド処理を開始しました。', payload['message']
      assert_equal 'queued', payload.dig('progress', 'state')
      assert_equal '待機中', payload.dig('progress', 'status')
    end

    test 'joysound touhou operation receives progress callback' do
      progress_id = SecureRandom.uuid
      fetch = lambda do |progress: nil|
        progress.call(percentage: 61, status: '外部サイト取得中', label: 'JOYSOUND東方系検索結果を保存しています')
      end

      original_fetch = JoysoundSong.method(:fetch_joysound_touhou_songs)
      JoysoundSong.define_singleton_method(:fetch_joysound_touhou_songs, &fetch)
      begin
        perform_enqueued_jobs do
          post operation_admin_joysound_songs_path, params: { operation: 'fetch_joysound_touhou_songs', operation_progress_id: progress_id }
        end
      ensure
        JoysoundSong.define_singleton_method(:fetch_joysound_touhou_songs, &original_fetch)
      end

      assert_redirected_to admin_joysound_songs_path
      progress = OperationProgress.read(progress_id)
      assert_equal 'completed', progress[:state]
      assert_equal 100, progress[:percentage]
    end

    test 'handler operation receives progress callback and completes progress' do
      progress_id = SecureRandom.uuid
      runner = lambda do |progress: nil|
        progress.call(percentage: 48, status: 'URL検証中', label: 'アーティストURLを検証しています')
        Admin::OperationRunner::Result.new(message: 'ok', download_data: nil, download_filename: nil, download_content_type: nil)
      end

      original_handler = Admin::OperationRunner.instance_method(:validate_display_artist_urls)
      Admin::OperationRunner.define_method(:validate_display_artist_urls, &runner)
      begin
        post operation_admin_display_artists_path, params: { operation: 'validate_display_artist_urls', operation_progress_id: progress_id }
      ensure
        Admin::OperationRunner.define_method(:validate_display_artist_urls, original_handler)
      end

      assert_redirected_to admin_display_artists_path
      progress = OperationProgress.read(progress_id)
      assert_equal 'completed', progress[:state]
      assert_equal 100, progress[:percentage]
    end

    test 'head request to action page does not execute operation' do
      DisplayArtist.create!(karaoke_type: 'DAM', name: 'Head Safe Orphan', url: 'https://example.com/head-safe-orphan')

      assert_no_difference -> { DisplayArtist.count } do
        head operation_admin_display_artists_path(operation: 'cleanup_orphan_display_artists')
      end

      assert_response :success
    end

    test 'renders member action page with action key' do
      get operation_admin_karaoke_delivery_model_path(@delivery_model, operation: 'move_higher')

      assert_response :success
      assert_select 'h1', text: '上へ移動'
      assert_select 'form[data-admin-operation-form][data-admin-operation-action="MoveHigher"]'
    end

    test 'requires selected songs for selection-only export operation' do
      post operation_admin_songs_path, params: { operation: 'export_songs' }

      assert_redirected_to admin_songs_path
      follow_redirect!
      assert_select '.admin-flash-alert', text: '対象を選択してください。'
    end

    test 'exports selected songs tsv from operation' do
      other_artist = DisplayArtist.create!(karaoke_type: 'JOYSOUND', name: 'Other Artist', url: 'https://example.com/other-artist')
      other_song = Song.create!(display_artist: other_artist, karaoke_type: 'JOYSOUND', title: 'Other Song', url: 'https://example.com/other-song')

      post operation_admin_songs_path, params: { operation: 'export_songs', selected_ids: [@song.id] }

      assert_response :success
      assert_includes response.body, "DAM\tZUN\tKaraoke Song"
      assert_not_includes response.body, other_song.title
    end

    test 'invalid selected song ids do not broaden export scope' do
      post operation_admin_songs_path, params: { operation: 'export_songs', selected_ids: ['invalid-id'] }

      assert_redirected_to admin_songs_path
      follow_redirect!
      assert_select '.admin-flash-alert', text: '対象を選択してください。'
    end

    test 'imports songs with original songs tsv from operation' do
      another_original_song = OriginalSong.create!(code: '000102', original: @original, title: 'ほおずきみたいに紅い魂', composer: 'ZUN', track_number: 2)
      upload = Rack::Test::UploadedFile.new(import_tsv_path(another_original_song), 'text/tab-separated-values')

      post operation_admin_songs_path, params: {
        operation: operation_index(:song, :import_songs_with_original_songs),
        operation_fields: { tsv_file: upload }
      }

      assert_redirected_to admin_songs_path
      @song.reload
      assert_equal [another_original_song], @song.original_songs.to_a
      assert_equal 'https://youtube.example/new', @song.youtube_url
    end

    test 'runs url input operation' do
      captured_url = nil
      with_stubbed_class_method(DamSong, :fetch_dam_song, ->(url) { captured_url = url }) do
        perform_enqueued_jobs do
          post operation_admin_dam_songs_path, params: {
            operation: operation_index(:dam_song, :fetch_dam_song),
            operation_fields: { dam_song_url: Constants::Karaoke::Dam::SONG_URL }
          }
        end
      end

      assert_redirected_to admin_dam_songs_path
      assert_equal Constants::Karaoke::Dam::SONG_URL, captured_url
    end

    test 'downloads invalid display artists tsv from validate operation' do
      result = {
        checked: 1,
        invalid: 1,
        deleted: 0,
        invalid_records: [{ id: @display_artist.id, name: @display_artist.name, karaoke_type: @display_artist.karaoke_type, url: @display_artist.url }],
        deleted_records: [],
        errors: []
      }
      validator = Struct.new(:result) do
        def validate_all = result
      end.new(result)

      with_stubbed_class_method(DisplayArtistUrlValidator, :new, lambda { |delete_invalid:, progress: nil|
        flunk('delete_invalid should be false') if delete_invalid
        progress&.call(percentage: 25, status: 'URL検証中', label: '検証中')

        validator
      }) do
        post operation_admin_display_artists_path, params: { operation: operation_index(:display_artist, :validate_display_artist_urls) }
      end

      assert_response :success
      assert_includes response.headers['Content-Disposition'], 'invalid_display_artists.tsv'
      assert_includes response.body, "id\tname\tkaraoke_type\turl"
      assert_includes response.body, @display_artist.url
    end

    test 'downloads deleted orphan display artists tsv from cleanup operation' do
      orphan = DisplayArtist.create!(karaoke_type: 'DAM', name: 'Orphan', url: 'https://example.com/orphan')

      assert_difference -> { DisplayArtist.count }, -1 do
        post operation_admin_display_artists_path, params: { operation: operation_index(:display_artist, :cleanup_orphan_display_artists) }
      end

      assert_response :success
      assert_includes response.headers['Content-Disposition'], 'deleted_orphan_display_artists.tsv'
      assert_includes response.body, orphan.id
    end

    test 'runs joysound music post maintenance operation through service' do
      maintenance_result = {
        cleanup: { deleted: 1, errors: [] },
        fetch: { fetched: 2, errors: [] },
        refresh: { deleted: 3, errors: [] },
        update_deadlines: { updated: 4, errors: [] }
      }
      manager = Struct.new(:result) do
        def perform_full_maintenance(progress: nil)
          progress&.call(percentage: 50, status: 'メンテナンス中', label: '実行中')
          result
        end
      end.new(maintenance_result)

      with_stubbed_class_method(JoysoundMusicPostManager, :new, -> { manager }) do
        perform_enqueued_jobs do
          post operation_admin_joysound_music_posts_path, params: {
            operation: operation_index(:joysound_music_post, :perform_full_joysound_music_post_maintenance)
          }
        end
      end

      assert_redirected_to admin_joysound_music_posts_path
      follow_redirect!
      assert_select '.admin-flash-notice', text: /フルメンテナンスのバックグラウンド処理を開始しました/
    end

    test 'rejects invalid url input operation' do
      progress_id = SecureRandom.uuid
      perform_enqueued_jobs do
        post operation_admin_dam_songs_path, params: {
          operation: operation_index(:dam_song, :fetch_dam_song),
          operation_progress_id: progress_id,
          operation_fields: { dam_song_url: 'https://example.com/not-dam' }
        }
      end

      assert_redirected_to admin_dam_songs_path
      progress = OperationProgress.read(progress_id)
      assert_equal 'failed', progress[:state]
      assert_equal 'DAMの楽曲URLではありません。', progress[:detail]
    end

    private

    def operation_index(resource_key, handler)
      ResourceRegistry.fetch(resource_key).operations.index { |operation| operation.handler == handler }
    end

    def import_tsv_path(original_song)
      path = Rails.root.join("tmp/songs_#{SecureRandom.hex(8)}.tsv")
      File.write(path, [
        "id\tkaraoke_type\tdisplay_artist_name\ttitle\toriginal_songs\tyoutube_url\tnicovideo_url\tapple_music_url\tyoutube_music_url\tspotify_url\tline_music_url",
        "#{@song.id}\tDAM\tZUN\tKaraoke Song\t#{original_song.title}\thttps://youtube.example/new\t\t\t\t\t"
      ].join("\n"))
      path
    end

    def with_stubbed_class_method(klass, method_name, replacement)
      original = klass.method(method_name)
      klass.define_singleton_method(method_name, &replacement)
      yield
    ensure
      klass.define_singleton_method(method_name) do |*args, **kwargs, &block|
        original.call(*args, **kwargs, &block)
      end
    end

    def resource_records
      {
        ResourceRegistry.fetch(:original) => @original,
        ResourceRegistry.fetch(:original_song) => @original_song,
        ResourceRegistry.fetch(:karaoke_delivery_model) => @delivery_model,
        ResourceRegistry.fetch(:circle) => @circle,
        ResourceRegistry.fetch(:song) => @song,
        ResourceRegistry.fetch(:display_artist) => @display_artist,
        ResourceRegistry.fetch(:dam_song) => @dam_song,
        ResourceRegistry.fetch(:dam_artist_url) => @dam_artist_url,
        ResourceRegistry.fetch(:joysound_song) => @joysound_song,
        ResourceRegistry.fetch(:joysound_music_post) => @joysound_music_post,
        ResourceRegistry.fetch(:song_with_dam_ouchikaraoke) => @dam_ouchikaraoke,
        ResourceRegistry.fetch(:song_with_joysound_utasuki) => @joysound_utasuki
      }
    end
  end
end
