# frozen_string_literal: true

module Admin
  module Resources
    module JoysoundResources
      private

      def joysound_song
        resource(
          key: :joysound_song,
          model: JoysoundSong,
          label: 'JOYSOUND楽曲',
          title: :display_title,
          order: { created_at: :desc },
          search: { display_title_cont: :q },
          filters: [
            joysound_service_filter
          ],
          fields: [
            field(:display_title, label: '表示タイトル', readonly: true, sortable: true, link: true),
            field(:url, label: 'URL', type: :url, readonly: true, sortable: true),
            field(:smartphone_service_enabled, label: 'スマートフォンサービス', type: :boolean, readonly: true, sortable: true),
            field(:home_karaoke_enabled, label: '家庭用カラオケ', type: :boolean, readonly: true, sortable: true)
          ],
          operations: [
            operation('JOYSOUND候補一覧を取得', key: :fetch_joysound_touhou_songs, method_name: :fetch_joysound_candidate_songs, group: '外部取得', async: true, description: ResourceRegistry::FETCH_JOYSOUND_TOUHOU_SONGS_DESCRIPTION, confirmation: '外部サイトへアクセスしてJOYSOUND候補一覧を取得・更新します。実行しますか？'),
            operation('JOYSOUND楽曲URLから候補を追加', handler: :fetch_joysound_detail, group: 'URL指定取得', async: true, confirmation: '指定URLからJOYSOUND候補を追加します。実行しますか？', inputs: [{ name: :joysound_url, label: 'JOYSOUND楽曲URL', type: :text }])
          ]
        )
      end

      def joysound_music_post
        resource(
          key: :joysound_music_post,
          model: JoysoundMusicPost,
          label: 'ミュージックポスト(JOYSOUND)',
          title: ->(record) { "[#{record.artist}] #{record.title}" },
          order: { created_at: :desc },
          search: { artist_cont: :q, title_cont: :q, m: 'or' },
          filters: [
            presence_filter(:joysound_url, label: 'JOYSOUND URL', present_label: 'URLあり', blank_label: 'URLなし'),
            date_status_filter(:delivery_deadline_on, label: '配信期限')
          ],
          fields: [
            field(:title, label: 'タイトル', readonly: true, sortable: true, link: true),
            field(:artist, label: 'アーティスト', readonly: true, sortable: true),
            field(:producer, label: 'プロデューサー', readonly: true, sortable: true),
            field(:delivery_deadline_on, label: '配信期限', type: :date, readonly: true, sortable: true),
            field(:url, label: 'URL', type: :url, index: false, sortable: true),
            field(:joysound_url, label: 'JOYSOUND URL', type: :url, index: false, sortable: true)
          ],
          operations: [
            operation('ミュージックポスト一覧を取得', key: :fetch_music_post, method_name: :fetch_music_post_entries, group: '外部取得', async: true, confirmation: '外部サイトへアクセスしてミュージックポスト一覧を取得します。実行しますか？'),
            operation('JOYSOUND URLを取得', key: :fetch_music_post_song_joysound_url, method_name: :link_music_posts_to_joysound_urls, group: '外部取得', async: true, confirmation: '外部サイトへアクセスしてJOYSOUND URLを取得します。実行しますか？'),
            operation(
              '期限切れを削除',
              handler: :cleanup_expired_joysound_music_posts,
              group: '検証・削除',
              async: true,
              confirmation: '期限切れのミュージックポストを検証し、無効なレコードを削除します。実行しますか？',
              inputs: [
                { name: :dry_run, label: 'プレビューのみ', description: '削除せず対象を確認する', type: :checkbox, checked: true, required: false }
              ]
            ),
            operation(
              'フルメンテナンス',
              handler: :perform_full_joysound_music_post_maintenance,
              group: 'メンテナンス',
              async: true,
              description: ResourceRegistry::FULL_JOYSOUND_MUSIC_POST_MAINTENANCE_DESCRIPTION,
              confirmation: 'JOYSOUNDミュージックポストの全メンテナンスを実行します。実行しますか？'
            )
          ],
          strong_parameters: %i[joysound_url]
        )
      end

      def song_with_joysound_utasuki
        resource(
          key: :song_with_joysound_utasuki,
          model: SongWithJoysoundUtasuki,
          label: 'JOYSOUNDうたスキ',
          title: :url,
          navigation: false,
          includes: [:song],
          filters: [
            association_exact_filter(:karaoke_type, label: 'カラオケ種別', association: :song, column: :karaoke_type, options: karaoke_type_value_options),
            date_status_filter(:delivery_deadline_date, label: '配信期限')
          ],
          fields: [
            field(:song, label: 'カラオケ配信曲', type: :belongs_to, form: false, link: true, sortable: true),
            field(:song_id, label: 'カラオケ配信曲', type: :belongs_to_select, index: false, show: false, readonly: true, options: -> { Song.order(:title).limit(500).pluck(:title, :id) }),
            field(:delivery_deadline_date, label: '配信期限', type: :date, readonly: true, sortable: true),
            field(:url, label: 'URL', type: :url, readonly: true, sortable: true)
          ]
        )
      end
    end
  end
end
