# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module Admin
  module ResourceRegistryDefinitions
    include ResourceRegistryBuilder
    include Resources::MasterResources

    OPERATION_DESCRIPTIONS = ResourceRegistry::OPERATION_DESCRIPTIONS
    FETCH_JOYSOUND_TOUHOU_SONGS_DESCRIPTION = ResourceRegistry::FETCH_JOYSOUND_TOUHOU_SONGS_DESCRIPTION
    FULL_JOYSOUND_MUSIC_POST_MAINTENANCE_DESCRIPTION = ResourceRegistry::FULL_JOYSOUND_MUSIC_POST_MAINTENANCE_DESCRIPTION

    private

    def build_resources
      [
        original,
        original_song,
        karaoke_delivery_model,
        circle,
        song,
        display_artist,
        dam_song,
        dam_artist_url,
        joysound_song,
        joysound_music_post,
        song_with_dam_ouchikaraoke,
        song_with_joysound_utasuki
      ]
    end

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
          operation('DAM候補をカラオケ楽曲へ登録', key: :fetch_dam_songs, method_name: :register_dam_songs_from_candidates, group: '外部取得', async: true, confirmation: '外部サイトへアクセスしてDAM候補をカラオケ楽曲へ登録します。実行しますか？'),
          operation('DAM配信機種を再同期', key: :update_dam_delivery_models, method_name: :sync_dam_delivery_models, group: '外部取得', async: true, confirmation: '外部サイトへアクセスしてDAM配信機種を再同期します。実行しますか？'),
          operation('JOYSOUND候補をカラオケ楽曲へ登録', key: :fetch_joysound_songs, method_name: :register_joysound_songs_from_candidates, group: '外部取得', async: true, confirmation: '外部サイトへアクセスしてJOYSOUND候補をカラオケ楽曲へ登録します。実行しますか？'),
          operation('ミュージックポストをカラオケ楽曲へ登録', handler: :fetch_joysound_music_post_song, group: 'ミュージックポスト', async: true, confirmation: '外部サイトへアクセスしてミュージックポストをカラオケ楽曲へ登録します。実行しますか？'),
          operation('ミュージックポストURLを検証', handler: :refresh_joysound_music_post_song, group: 'ミュージックポスト', async: true, confirmation: '外部サイトへアクセスして無効な楽曲を削除します。実行しますか？'),
          operation('うたスキ配信期限を反映', handler: :update_joysound_music_post_delivery_deadline_dates, group: 'ミュージックポスト', async: true, confirmation: '配信期限を一括更新します。実行しますか？')
        ],
        strong_parameters: %i[youtube_url nicovideo_url apple_music_url youtube_music_url spotify_url line_music_url]
      )
    end

    def display_artist
      resource(
        key: :display_artist,
        model: DisplayArtist,
        label: 'アーティスト',
        title: ->(record) { "[#{record.karaoke_type}] #{record.name}" },
        includes: %i[circles songs],
        order: { created_at: :desc },
        search: { name_cont: :q },
        filters: [
          karaoke_type_filter,
          association_presence_filter(:circles, label: 'サークル', association: :circles),
          association_presence_filter(:songs, label: '曲', association: :songs),
          presence_filter(:name_reading, label: '読み', present_label: '読みあり', blank_label: '読みなし')
        ],
        fields: [
          field(:circles, label: 'サークル', show: false, form: false, helper: ->(record) { record.circles.map(&:name).join('、') }),
          field(:circle_ids, label: 'サークル', type: :has_many_select, index: false, show: false, form: false, options: -> { Circle.order(:name).pluck(:name, :id) }),
          field(:karaoke_type, label: 'カラオケ種別', readonly: true, sortable: true),
          field(:name, label: 'アーティスト名', readonly: true, sortable: true),
          field(:name_reading, label: 'アーティスト名読み', sortable: true),
          field(:url, label: 'URL', type: :url, sortable: true)
        ],
        associations: %i[circles songs dam_songs],
        operations: [
          operation('DAMアーティスト読みを補完', key: :fetch_dam_artist, method_name: :fill_dam_artist_readings, group: '外部取得', async: true, confirmation: '外部サイトへアクセスしてDAMアーティスト読みを補完します。実行しますか？'),
          operation('JOYSOUNDアーティスト読みを補完', key: :fetch_joysound_artist, method_name: :fill_joysound_artist_readings, group: '外部取得', async: true, confirmation: '外部サイトへアクセスしてJOYSOUNDアーティスト読みを補完します。実行しますか？'),
          operation('うたスキアーティストを登録', key: :fetch_joysound_music_post_artist, method_name: :register_joysound_music_post_artists, group: '外部取得', async: true, confirmation: '外部サイトへアクセスしてうたスキアーティストを登録します。実行しますか？'),
          operation('URLを検証', handler: :validate_display_artist_urls, group: '検証・削除', confirmation: 'アーティストURLを検証します。実行しますか？'),
          operation(
            '無効なアーティストを削除',
            handler: :cleanup_invalid_display_artists,
            group: '検証・削除',
            confirmation: 'URLが無効なアーティストを削除します。実行しますか？',
            inputs: [
              { name: :dry_run, label: 'プレビューのみ', description: '削除せず対象をTSVで確認する', type: :checkbox, checked: true, required: false }
            ]
          ),
          operation(
            '孤立アーティストを削除',
            handler: :cleanup_orphan_display_artists,
            group: '検証・削除',
            confirmation: '楽曲が紐づいていないアーティストを削除します。実行しますか？',
            inputs: [
              { name: :dry_run, label: 'プレビューのみ', description: '削除せず対象を確認する', type: :checkbox, checked: true, required: false },
              { name: :export_tsv, label: '削除結果TSV', description: '削除したアーティストをTSVで出力する', type: :checkbox, checked: true, required: false }
            ]
          )
        ],
        strong_parameters: [:name_reading, :url, { circle_ids: [] }]
      )
    end

    def dam_song
      resource(
        key: :dam_song,
        model: DamSong,
        label: 'DAM楽曲',
        title: ->(record) { "[#{record.display_artist&.name}] #{record.title}" },
        includes: [:display_artist],
        order: { created_at: :desc },
        search: { display_artist_name_cont: :q, title_cont: :q, m: 'or' },
        filters: [
          artist_circle_filter
        ],
        fields: [
          field(:display_artist, label: 'アーティスト', type: :belongs_to, form: false, link: true, sortable: true),
          field(:display_artist_id, label: 'アーティスト', type: :belongs_to_select, index: false, show: false, options: -> { DisplayArtist.dam.order(:name).limit(500).pluck(:name, :id) }),
          field(:title, label: 'タイトル', readonly: true, sortable: true, link: true),
          field(:url, label: 'URL', type: :url, readonly: true, sortable: true)
        ],
        operations: [
          operation('DAM候補一覧を取得', key: :fetch_dam_touhou_songs, method_name: :fetch_dam_candidate_songs, group: '外部取得', async: true, estimated_seconds: 40, confirmation: '外部サイトへアクセスしてDAM候補一覧を取得します。実行しますか？'),
          operation('DAM楽曲URLから候補を追加', handler: :fetch_dam_song, group: 'URL指定取得', async: true, confirmation: '指定URLからDAM候補を追加します。実行しますか？', inputs: [{ name: :dam_song_url, label: 'DAM楽曲URL', type: :text, placeholder: Constants::Karaoke::Dam::SONG_URL }])
        ]
      )
    end

    def dam_artist_url
      resource(
        key: :dam_artist_url,
        model: DamArtistUrl,
        label: 'DAMアーティストURL',
        title: :url,
        search: { url_cont: :q },
        filters: [
          dam_artist_url_registration_filter
        ],
        fields: [
          field(:url, label: 'URL', type: :url, link: true, sortable: true)
        ]
      )
    end

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
          operation('JOYSOUND候補一覧を取得', key: :fetch_joysound_touhou_songs, method_name: :fetch_joysound_candidate_songs, group: '外部取得', async: true, description: FETCH_JOYSOUND_TOUHOU_SONGS_DESCRIPTION, confirmation: '外部サイトへアクセスしてJOYSOUND候補一覧を取得・更新します。実行しますか？'),
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
            description: FULL_JOYSOUND_MUSIC_POST_MAINTENANCE_DESCRIPTION,
            confirmation: 'JOYSOUNDミュージックポストの全メンテナンスを実行します。実行しますか？'
          )
        ],
        strong_parameters: %i[joysound_url]
      )
    end

    def song_with_dam_ouchikaraoke
      resource(
        key: :song_with_dam_ouchikaraoke,
        model: SongWithDamOuchikaraoke,
        label: 'DAMおうちカラオケ',
        title: :url,
        navigation: false,
        includes: [:song],
        filters: [
          association_exact_filter(:karaoke_type, label: 'カラオケ種別', association: :song, column: :karaoke_type, options: karaoke_type_value_options)
        ],
        fields: [
          field(:song, label: 'カラオケ配信曲', type: :belongs_to, form: false, link: true, sortable: true),
          field(:song_id, label: 'カラオケ配信曲', type: :belongs_to_select, index: false, show: false, readonly: true, options: -> { Song.order(:title).limit(500).pluck(:title, :id) }),
          field(:url, label: 'URL', type: :url, readonly: true, sortable: true)
        ]
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

    def exact_filter(name, label:, options:)
      filter(name, label:, options:) do |scope, value|
        scope.where(name => value)
      end
    end

    def association_exact_filter(name, label:, association:, column:, options:)
      filter(name, label:, options:) do |scope, value|
        reflection = scope.klass.reflect_on_association(association)
        next scope unless reflection

        scope.left_outer_joins(association).where(reflection.klass.table_name => { column => value }).distinct
      end
    end

    def boolean_filter(name, label:, true_label:, false_label:)
      filter(name, label:, type: :radio, options: { true_value: true_label, false_value: false_label }) do |scope, value|
        case value
        when 'true_value'
          scope.where(name => true)
        when 'false_value'
          scope.where(name => false)
        else
          scope
        end
      end
    end

    def presence_filter(name, label:, present_label:, blank_label:)
      filter(name, label:, type: :radio, options: { present: present_label, blank: blank_label }) do |scope, value|
        case value
        when 'present'
          scope.where.not(name => '')
        when 'blank'
          scope.where(name => '')
        else
          scope
        end
      end
    end

    def association_presence_filter(name, label:, association:)
      filter(name, label:, type: :radio, options: { present: "#{label}あり", blank: "#{label}なし" }) do |scope, value|
        case value
        when 'present'
          scope.left_outer_joins(association).where.not(association => { id: nil }).distinct
        when 'blank'
          scope.where.missing(association)
        else
          scope
        end
      end
    end

    def date_status_filter(name, label:)
      filter(name, label:, type: :radio, options: { active: '期限内', expired: '期限切れ' }) do |scope, value|
        case value
        when 'active'
          scope.where(name => Date.current..)
        when 'expired'
          scope.where(name => ...Date.current)
        else
          scope
        end
      end
    end

    def delivery_karaoke_type_filter
      exact_filter(:karaoke_type, label: 'カラオケ種別', options: { DAM: 'DAM', JOYSOUND: 'JOYSOUND' })
    end

    def karaoke_type_filter
      filter(
        :karaoke_type,
        label: 'カラオケ種別',
        type: :radio,
        options: karaoke_type_options
      ) do |scope, value|
        case value
        when 'dam'
          scope.dam
        when 'joysound'
          scope.joysound
        when 'joysound_music_post'
          scope.music_post
        else
          scope
        end
      end
    end

    def karaoke_type_options
      {
        dam: 'DAM',
        joysound: 'JOYSOUND',
        joysound_music_post: 'JOYSOUND(うたスキ)'
      }
    end

    def karaoke_type_value_options
      {
        'DAM' => 'DAM',
        'JOYSOUND' => 'JOYSOUND',
        'JOYSOUND(うたスキ)' => 'JOYSOUND(うたスキ)'
      }
    end

    def music_service_filter
      filter(
        :music_service,
        label: '音楽配信',
        type: :presence_groups,
        options: {
          apple_music: 'Apple',
          youtube_music: 'YT Music',
          spotify: 'Spotify',
          line_music: 'LINE'
        }
      ) do |scope, values|
        apply_music_service_filters(scope, values)
      end
    end

    def video_service_filter
      filter(
        :video_service,
        label: '動画',
        type: :presence_groups,
        options: {
          youtube: 'YouTube',
          nicovideo: 'ニコニコ'
        }
      ) do |scope, values|
        apply_video_service_filters(scope, values)
      end
    end

    def apply_music_service_filters(scope, values)
      apply_presence_group_filters(
        scope,
        values,
        apple_music: :apple_music_url,
        youtube_music: :youtube_music_url,
        spotify: :spotify_url,
        line_music: :line_music_url
      )
    end

    def apply_video_service_filters(scope, values)
      apply_presence_group_filters(scope, values, youtube: :youtube_url, nicovideo: :nicovideo_url)
    end

    def apply_presence_group_filters(scope, values, columns)
      values.reduce(scope) do |filtered_scope, (key, state)|
        column = columns[key.to_sym]
        next filtered_scope unless column

        case state
        when 'present'
          filtered_scope.where.not(column => '')
        when 'missing'
          filtered_scope.where(column => '')
        else
          filtered_scope
        end
      end
    end

    def artist_circle_filter
      filter(:artist_circle, label: 'アーティストのサークル', type: :radio, options: { present: 'サークルあり', blank: 'サークルなし' }) do |scope, value|
        case value
        when 'present'
          scope.left_outer_joins(display_artist: :circles).where.not(circles: { id: nil }).distinct
        when 'blank'
          scope.left_outer_joins(display_artist: :circles).where(circles: { id: nil }).distinct
        else
          scope
        end
      end
    end

    def dam_artist_url_registration_filter
      filter(:registration, label: '登録状況', type: :radio, options: { registered: '登録済み', unregistered: '未登録' }) do |scope, value|
        registered_urls = DisplayArtist.dam.select(:url)
        case value
        when 'registered'
          scope.where(url: registered_urls)
        when 'unregistered'
          scope.where.not(url: registered_urls)
        else
          scope
        end
      end
    end

    def joysound_service_filter
      filter(
        :service_enabled,
        label: '対応サービス',
        type: :radio,
        options: {
          smartphone: 'スマートフォン',
          home_karaoke: '家庭用カラオケ',
          both: '両方有効',
          none: 'どちらも無効'
        }
      ) do |scope, value|
        case value
        when 'smartphone'
          scope.where(smartphone_service_enabled: true)
        when 'home_karaoke'
          scope.where(home_karaoke_enabled: true)
        when 'both'
          scope.where(smartphone_service_enabled: true, home_karaoke_enabled: true)
        when 'none'
          scope.where(smartphone_service_enabled: false, home_karaoke_enabled: false)
        else
          scope
        end
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
