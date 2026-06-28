# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module Admin
  module ResourceRegistryDefinitions
    include ResourceRegistryBuilder
    include Resources::MasterResources
    include Resources::SongResources
    include Resources::DisplayArtistResources
    include Resources::DamResources

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
