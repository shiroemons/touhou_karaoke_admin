# frozen_string_literal: true

module Admin
  module Resources
    module SongResources
      private

      def song
        resource(
          key: :song,
          model: Song,
          label: 'カラオケ配信曲',
          title: ->(record) { "[#{record.karaoke_type}] #{record.title}" },
          includes: [:display_artist, :karaoke_delivery_models, { original_songs: :original }, :song_with_dam_ouchikaraoke, :song_with_joysound_utasuki],
          order: { created_at: :desc },
          search: { title_cont: :q, display_artist_name_cont: :q, m: 'or' },
          filters: [
            karaoke_type_filter,
            filter(:original_link, label: '原曲紐付け', type: :radio, options: { linked: 'あり', missing: 'なし' }) do |scope, value|
              case value
              when 'linked'
                scope.with_original_songs
              when 'missing'
                scope.missing_original_songs
              else
                scope
              end
            end,
            filter(
              :original_category,
              label: '分類',
              type: :radio,
              options: { touhou_arrange: '東方アレンジ', original_or_other: 'オリジナル・その他', missing: '未紐付け' }
            ) do |scope, value|
              case value
              when 'touhou_arrange'
                scope.touhou_arrange
              when 'original_or_other'
                scope.original_or_other
              when 'missing'
                scope.missing_original_songs
              else
                scope
              end
            end,
            video_service_filter,
            music_service_filter
          ],
          fields: [
            field(:karaoke_type, label: 'カラオケ種別', readonly: true, sortable: true),
            field(:song_number, label: '曲番号', index: false, readonly: true),
            field(:title, label: 'タイトル', readonly: true, sortable: true, link: true),
            field(:title_reading, label: 'タイトル読み', index: false, readonly: true, sortable: true),
            field(:display_artist, label: 'アーティスト', type: :belongs_to, form: false, link: true, sortable: true),
            field(:display_artist_id, label: 'アーティスト', type: :belongs_to_select, index: false, show: false, readonly: true, options: -> { DisplayArtist.order(:name).limit(500).pluck(:name, :id) }),
            field(:original_songs_link_status, label: '原曲紐付け', type: :badge, form: false),
            field(:original_songs_count_label, label: '原曲数', form: false),
            field(:original_song_category_label, label: '分類', type: :badge, form: false),
            field(:video_services, label: '動画', type: :service_status, show: false, form: false, options: { youtube_url: 'YouTube', nicovideo_url: 'ニコニコ' }),
            field(:music_services, label: '音楽配信', type: :service_status, show: false, form: false, options: { apple_music_url: 'Apple', youtube_music_url: 'YT Music', spotify_url: 'Spotify', line_music_url: 'LINE' }),
            field(:url, label: 'URL', type: :url, index: false, readonly: true),
            field(:touhou?, label: 'touhou', type: :boolean_mark, index: false, form: false),
            field(:youtube_url, label: 'YouTube URL', type: :url, index: false),
            field(:nicovideo_url, label: 'ニコニコ動画 URL', type: :url, index: false),
            field(:apple_music_url, label: 'Apple Music URL', type: :url, index: false),
            field(:youtube_music_url, label: 'YouTube Music URL', type: :url, index: false),
            field(:spotify_url, label: 'Spotify URL', type: :url, index: false),
            field(:line_music_url, label: 'LINE MUSIC URL', type: :url, index: false)
          ],
          associations: %i[karaoke_delivery_models original_songs song_with_dam_ouchikaraoke song_with_joysound_utasuki],
          operations: [
            operation('楽曲TSVをエクスポート', handler: :export_songs, group: 'TSV入出力', selection: :required),
            operation('原曲未設定TSVをエクスポート', handler: :export_missing_original_songs, group: 'TSV入出力'),
            operation('原曲付き楽曲TSVをインポート', handler: :import_songs_with_original_songs, group: 'TSV入出力', inputs: [{ name: :tsv_file, label: 'TSVファイル', type: :file, accept: 'text/tab-separated-values' }]),
            operation('DAM候補をカラオケ楽曲へ登録', key: :fetch_dam_songs, method_name: :register_dam_songs_from_candidates, group: '外部取得', async: true, repeat_while_created: true, max_attempts: 3, confirmation: '外部サイトへアクセスしてDAM候補をカラオケ楽曲へ登録します。実行しますか？'),
            operation('DAM配信機種を再同期', key: :update_dam_delivery_models, method_name: :sync_dam_delivery_models, group: '外部取得', async: true, confirmation: '外部サイトへアクセスしてDAM配信機種を再同期します。実行しますか？'),
            operation('JOYSOUND候補をカラオケ楽曲へ登録', key: :fetch_joysound_songs, method_name: :register_joysound_songs_from_candidates, group: '外部取得', async: true, repeat_while_created: true, max_attempts: 3, confirmation: '外部サイトへアクセスしてJOYSOUND候補をカラオケ楽曲へ登録します。実行しますか？'),
            operation('ミュージックポストをカラオケ楽曲へ登録', handler: :fetch_joysound_music_post_song, group: 'ミュージックポスト', async: true, repeat_while_created: true, max_attempts: 3, confirmation: '外部サイトへアクセスしてミュージックポストをカラオケ楽曲へ登録します。実行しますか？'),
            operation('ミュージックポストURLを検証', handler: :refresh_joysound_music_post_song, group: 'ミュージックポスト', async: true, confirmation: '外部サイトへアクセスして無効な楽曲を削除します。実行しますか？'),
            operation('うたスキ配信期限を反映', handler: :update_joysound_music_post_delivery_deadline_dates, group: 'ミュージックポスト', async: true, confirmation: '配信期限を一括更新します。実行しますか？')
          ],
          strong_parameters: %i[youtube_url nicovideo_url apple_music_url youtube_music_url spotify_url line_music_url]
        )
      end
    end
  end
end
