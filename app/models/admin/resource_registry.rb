# frozen_string_literal: true

module Admin
  Field = Data.define(:name, :label, :type, :index, :show, :form, :readonly, :sortable, :options, :link, :helper, :count_association)
  Filter = Data.define(:name, :label, :type, :options, :apply)
  Operation = Data.define(:key, :action_key, :label, :description, :method_name, :confirmation, :scope, :handler, :inputs, :group, :estimated_seconds, :selection, :async)

  Resource = Data.define(
    :key,
    :model,
    :label,
    :title,
    :navigation,
    :includes,
    :order,
    :search,
    :filters,
    :fields,
    :associations,
    :operations,
    :strong_parameters
  ) do
    def controller_name
      key.to_s.pluralize
    end

    def route_name
      key.to_s.pluralize
    end

    def param_key
      key
    end

    def index_fields
      fields.select(&:index)
    end

    def show_fields
      fields.select(&:show)
    end

    def form_fields
      fields.select { |field| field.form && !field.readonly }
    end

    def filter_by_name(name)
      filters.find { |filter| filter.name.to_s == name.to_s }
    end
  end

  class ResourceRegistry
    FULL_JOYSOUND_MUSIC_POST_MAINTENANCE_DESCRIPTION = <<~TEXT.freeze
      実行内容（順番）:
      1. 期限切れクリーンアップ: 配信期限切れのミュージックポストを検証し、無効なレコードを削除します。
      2. 楽曲取得: 未登録または期限間近のミュージックポストを優先して、JOYSOUND側の楽曲情報を取得します。
      3. URL確認: 取得済みミュージックポスト楽曲のURLを確認し、404など無効な楽曲を削除します。
      4. 配信期限更新: 残った楽曲の配信期限を外部サイトから取得して更新します。

      参照する外部URL:
      #{Constants::Karaoke::Joysound::SEARCH_URL}
      #{Constants::Karaoke::Joysound::MUSIC_POST_BASE_URL}

      外部サイトへアクセスし、削除・更新を伴います。実行後は結果メッセージとログを確認してください。
    TEXT

    FETCH_JOYSOUND_TOUHOU_SONGS_DESCRIPTION = <<~TEXT.freeze
      JOYSOUND.comの「東方系」ジャンル検索結果を巡回し、JOYSOUND楽曲一覧として登録・更新します。

      取得元URL:
      #{Constants::Karaoke::Joysound::TOUHOU_GENRE_URL}

      保存する内容:
      - 表示タイトル（曲名／歌手名）
      - JOYSOUND楽曲URL
      - スマホサービス対応有無
      - 家庭用カラオケ対応有無

      この操作は一覧データ（JOYSOUND候補）を更新する処理です。カラオケ楽曲への本登録、作曲者による東方判定、曲番号、配信機種などの詳細取得は、別操作の「JOYSOUND候補をカラオケ楽曲へ登録」で行います。
    TEXT

    OPERATION_DESCRIPTIONS = {
      'move_higher' => 'この配信機種の表示順を1つ上に移動します。一覧や詳細での配信機種の並び順に反映されます。',
      'move_lower' => 'この配信機種の表示順を1つ下に移動します。一覧や詳細での配信機種の並び順に反映されます。',
      'move_to_top' => 'この配信機種の表示順を先頭に移動します。一覧や詳細で最優先の位置に表示されます。',
      'move_to_bottom' => 'この配信機種の表示順を末尾に移動します。一覧や詳細で最後の位置に表示されます。',
      'export_songs' => '現在の楽曲データをTSV形式で出力します。楽曲ID、カラオケ種別、アーティスト、原曲、動画URL、音楽配信URLなどを含みます。',
      'export_missing_original_songs' => '原曲が未設定の楽曲だけをTSV形式で出力します。原曲紐付け作業の確認・編集用です。',
      'import_songs_with_original_songs' => 'TSVファイルを読み込み、楽曲の原曲紐付けと動画・音楽配信URLを更新します。TSV内の楽曲IDを基準に既存レコードを更新します。',
      'fetch_dam_songs' => <<~TEXT,
        DAM楽曲一覧に登録済みのURLを巡回し、DAM楽曲詳細をカラオケ楽曲として登録します。既にカラオケ楽曲へ登録済みの楽曲はスキップします。

        参照する外部URL:
        #{Constants::Karaoke::Dam::SONG_URL}
      TEXT
      'update_dam_delivery_models' => <<~TEXT,
        登録済みDAM楽曲の詳細ページを確認し、配信機種の紐付けを最新状態に更新します。

        参照する外部URL:
        #{Constants::Karaoke::Dam::SONG_URL}
      TEXT
      'fetch_joysound_songs' => <<~TEXT,
        JOYSOUND楽曲一覧に登録済みのURLを巡回し、作曲者が東方対象または許可リストに含まれる楽曲をカラオケ楽曲として登録します。曲番号、アーティスト、配信機種も取得します。

        参照する外部URL:
        #{Constants::Karaoke::Joysound::SEARCH_URL}
      TEXT
      'fetch_joysound_music_post_song' => <<~TEXT,
        JOYSOUNDミュージックポストの未登録URLや期限間近の楽曲を優先して確認し、うたスキ楽曲としてカラオケ楽曲へ登録・更新します。

        参照する外部URL:
        #{Constants::Karaoke::Joysound::SEARCH_URL}
      TEXT
      'refresh_joysound_music_post_song' => <<~TEXT,
        登録済みミュージックポスト楽曲のURL存在確認を行い、404など明確に無効な楽曲を削除します。ネットワークエラーの場合は削除せずスキップします。

        参照する外部URL:
        #{Constants::Karaoke::Joysound::SEARCH_URL}
      TEXT
      'update_joysound_music_post_delivery_deadline_dates' => 'JOYSOUNDミュージックポストの配信期限情報を参照し、カラオケ楽曲に紐づくうたスキ配信期限を一括更新します。',
      'fetch_dam_artist' => <<~TEXT,
        DAMアーティストURL一覧を巡回し、DAMアーティストの名前と読みを取得・更新します。読みが未設定のアーティストが対象です。

        参照する外部URL:
        #{Constants::Karaoke::Dam::BASE_URL}
      TEXT
      'fetch_joysound_artist' => <<~TEXT,
        JOYSOUNDアーティスト詳細ページを巡回し、JOYSOUNDアーティストの読みを取得・更新します。読みが未設定のアーティストが対象です。

        参照する外部URL:
        #{Constants::Karaoke::Joysound::BASE_URL}
      TEXT
      'fetch_joysound_music_post_artist' => <<~TEXT,
        JOYSOUNDミュージックポストのアーティスト名をJOYSOUND上で検索し、うたスキ用アーティスト情報を登録します。該当なしの場合は関連する未登録データを整理します。

        取得元URL:
        #{Constants::Karaoke::Joysound::BASE_URL}
      TEXT
      'validate_display_artist_urls' => <<~TEXT,
        登録済みアーティストURLの存在確認を行います。無効なURLが見つかった場合はTSVで出力し、レコード削除は行いません。

        参照する外部URL:
        登録済みの各アーティストURL（DAMまたはJOYSOUNDのアーティストページ）
      TEXT
      'cleanup_invalid_display_artists' => <<~TEXT,
        登録済みアーティストURLの存在確認を行い、無効かつ楽曲が紐づいていないアーティストだけを削除します。削除対象はTSVで出力します。

        参照する外部URL:
        登録済みの各アーティストURL（DAMまたはJOYSOUNDのアーティストページ）
      TEXT
      'cleanup_orphan_display_artists' => '楽曲が1件も紐づいていないアーティストを削除します。削除したアーティストはTSVで出力します。',
      'fetch_dam_touhou_songs' => <<~TEXT,
        DAMの東方系検索結果を巡回し、DAM楽曲一覧とDAMアーティストURLを登録・更新します。カラオケ楽曲への本登録は別操作の「DAM候補をカラオケ楽曲へ登録」で行います。

        取得元URL:
        #{Constants::Karaoke::Dam::SEARCH_URL}1
      TEXT
      'fetch_dam_song' => <<~TEXT,
        入力されたDAM楽曲URLから、曲名とアーティスト情報を取得し、DAM楽曲一覧へ登録・更新します。

        入力URLの形式:
        #{Constants::Karaoke::Dam::SONG_URL}
      TEXT
      'fetch_joysound_detail' => <<~TEXT,
        入力されたJOYSOUND楽曲URLから、表示タイトルを取得してJOYSOUND楽曲一覧へ登録・更新します。詳細なカラオケ楽曲登録は「JOYSOUND候補をカラオケ楽曲へ登録」で行います。

        入力URLの形式:
        #{Constants::Karaoke::Joysound::SEARCH_URL}/
      TEXT
      'fetch_music_post' => <<~TEXT,
        JOYSOUNDミュージックポストの東方関連ページを巡回し、タイトル、アーティスト、配信ユーザー、配信期限、Music Post URLを登録・更新します。

        取得元URL:
        #{Constants::Karaoke::Joysound::MUSIC_POST_ZUN_URL}
        #{Constants::Karaoke::Joysound::MUSIC_POST_AKIYAMA_URL}
      TEXT
      'fetch_music_post_song_joysound_url' => <<~TEXT,
        ミュージックポスト楽曲のアーティストページを検索し、Music Postレコードに対応するJOYSOUND楽曲URLを紐付けます。

        参照する外部URL:
        #{Constants::Karaoke::Joysound::BASE_URL}
      TEXT
      'cleanup_expired_joysound_music_posts' => <<~TEXT
        配信期限切れのミュージックポストを確認し、URLが存在しないレコードだけを削除します。URLが残っている場合は削除しません。

        参照する外部URL:
        #{Constants::Karaoke::Joysound::MUSIC_POST_BASE_URL}
      TEXT
    }.freeze

    NAVIGATION_GROUPS = {
      '作品マスタ' => %i[original original_song],
      '配信管理' => %i[circle display_artist song karaoke_delivery_model],
      'DAM' => %i[dam_song dam_artist_url],
      'JOYSOUND' => %i[joysound_song joysound_music_post]
    }.freeze

    class << self
      def all
        @all ||= build_resources.index_by(&:key)
      end

      def fetch(key)
        all.fetch(key.to_sym)
      end

      def navigable
        all.values.select(&:navigation)
      end

      def navigation_groups
        resources = navigable.index_by(&:key)
        groups = NAVIGATION_GROUPS.filter_map do |label, keys|
          grouped_resources = keys.filter_map { |key| resources.delete(key) }
          [label, grouped_resources] if grouped_resources.present?
        end
        groups << ['その他', resources.values] if resources.present?
        groups
      end

      private

      def field(name, label:, **options)
        attributes = {
          type: :text,
          index: true,
          show: true,
          form: true,
          readonly: false,
          sortable: false,
          options: nil,
          link: false,
          helper: nil,
          count_association: nil
        }.merge(options)
        Field.new(name:, label:, **attributes)
      end

      def filter(name, label:, options:, type: :auto, &block)
        Filter.new(name:, label:, type:, options:, apply: block)
      end

      def operation(label, **attributes)
        operation_key = attributes.fetch(:key, attributes.fetch(:handler, attributes.fetch(:method_name, label))).to_s
        Operation.new(
          key: operation_key,
          action_key: attributes.fetch(:action_key, operation_key.camelize),
          label:,
          description: attributes.fetch(:description, OPERATION_DESCRIPTIONS.fetch(operation_key, attributes.fetch(:confirmation, "#{label}を実行します。"))),
          method_name: attributes.fetch(:method_name, nil),
          confirmation: attributes.fetch(:confirmation, nil),
          scope: attributes.fetch(:scope, :collection),
          handler: attributes.fetch(:handler, nil),
          inputs: attributes.fetch(:inputs, []),
          group: attributes.fetch(:group, '操作'),
          estimated_seconds: attributes.fetch(:estimated_seconds, nil),
          selection: attributes.fetch(:selection, :none),
          async: attributes.fetch(:async, false)
        )
      end

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

      def resource(**attributes)
        model = attributes.fetch(:model)
        fields = fields_with_timestamp(attributes.fetch(:fields), model)

        Resource.new(
          key: attributes.fetch(:key),
          model:,
          label: attributes.fetch(:label),
          title: attributes.fetch(:title),
          navigation: attributes.fetch(:navigation, true),
          includes: attributes.fetch(:includes, []),
          order: attributes.fetch(:order, nil),
          search: attributes.fetch(:search, {}),
          filters: attributes.fetch(:filters, []),
          fields:,
          associations: attributes.fetch(:associations, []),
          operations: attributes.fetch(:operations, []),
          strong_parameters: attributes.fetch(:strong_parameters, nil) || fields.select(&:form).map(&:name)
        )
      end

      def fields_with_timestamp(fields, model)
        return fields unless model.column_names.include?('updated_at')
        return fields if fields.any? { |field| field.name.to_sym == :updated_at }

        fields + [
          field(:updated_at, label: '更新日時', type: :datetime, show: false, form: false, readonly: true, sortable: true)
        ]
      end

      def original
        resource(
          key: :original,
          model: Original,
          label: '原作',
          title: :title,
          search: { title_cont: :q },
          filters: [
            exact_filter(:original_type, label: '種別', options: Original.original_types.keys.index_with(&:itself))
          ],
          fields: [
            field(:code, label: 'コード', form: true, readonly: true, sortable: true),
            field(:title, label: '作品名', readonly: true, sortable: true),
            field(:short_title, label: '短縮タイトル', readonly: true, sortable: true),
            field(:original_type, label: '種別', type: :badge, readonly: true, options: Original.original_types.keys),
            field(:series_order, label: 'シリーズ順', type: :number, readonly: true, sortable: true)
          ],
          associations: %i[original_songs]
        )
      end

      def original_song
        resource(
          key: :original_song,
          model: OriginalSong,
          label: '原曲',
          title: ->(record) { "[#{record.original&.short_title}] #{record.title}" },
          includes: [:original],
          order: { code: :asc },
          search: { title_cont: :q },
          filters: [
            boolean_filter(:is_duplicate, label: '重複フラグ', true_label: '重複のみ', false_label: '重複以外'),
            association_exact_filter(:original_type, label: '原作種別', association: :original, column: :original_type, options: Original.original_types.keys.index_with(&:itself))
          ],
          fields: [
            field(:code, label: 'コード', form: true, readonly: true, sortable: true),
            field(:original, label: '原作', type: :belongs_to, form: false, link: true, sortable: true),
            field(:original_code, label: '原作', type: :belongs_to_select, index: false, show: false, readonly: true, options: -> { Original.order(:code).pluck(:title, :code) }),
            field(:title, label: '原曲名', readonly: true, sortable: true),
            field(:composer, label: '作曲者', readonly: true, sortable: true),
            field(:track_number, label: 'トラック番号', type: :number, readonly: true, sortable: true),
            field(:is_duplicate, label: '重複フラグ', type: :boolean, readonly: true, sortable: true)
          ],
          associations: %i[songs]
        )
      end

      def karaoke_delivery_model
        resource(
          key: :karaoke_delivery_model,
          model: KaraokeDeliveryModel,
          label: '配信機種',
          title: :name,
          order: { order: :asc },
          search: { name_cont: :q },
          filters: [delivery_karaoke_type_filter],
          fields: [
            field(:name, label: '機種名', sortable: true),
            field(:karaoke_type, label: 'カラオケ種別', type: :select, sortable: true, options: %w[DAM JOYSOUND]),
            field(:order, label: '表示順', type: :number, sortable: true)
          ],
          operations: [
            operation('上へ移動', method_name: :move_higher, scope: :member, group: '並び替え'),
            operation('下へ移動', method_name: :move_lower, scope: :member, group: '並び替え'),
            operation('先頭へ移動', method_name: :move_to_top, scope: :member, group: '並び替え'),
            operation('末尾へ移動', method_name: :move_to_bottom, scope: :member, group: '並び替え')
          ]
        )
      end

      def circle
        resource(
          key: :circle,
          model: Circle,
          label: 'サークル',
          title: :name,
          includes: [:display_artists],
          search: { name_cont: :q },
          filters: [
            association_presence_filter(:display_artists, label: 'アーティスト', association: :display_artists),
            association_presence_filter(:songs, label: '曲', association: :songs)
          ],
          fields: [
            field(:name, label: 'サークル名', sortable: true, link: true),
            field(:display_artists_count, label: 'アーティスト数', type: :number, form: false, sortable: true, count_association: :display_artists),
            field(:songs_count, label: '曲数', type: :number, form: false, sortable: true, count_association: :songs)
          ],
          associations: %i[display_artists songs]
        )
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
            field(:circle, label: 'サークル', type: :boolean_mark, show: false, form: false, helper: ->(record) { record.circles.present? }),
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
            operation('無効なアーティストを削除', handler: :cleanup_invalid_display_artists, group: '検証・削除', confirmation: 'URLが無効なアーティストを削除します。実行しますか？'),
            operation('孤立アーティストを削除', handler: :cleanup_orphan_display_artists, group: '検証・削除', confirmation: '楽曲が紐づいていないアーティストを削除します。実行しますか？')
          ],
          strong_parameters: %i[name_reading url]
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
            operation('DAM楽曲を取得', handler: :fetch_dam_song, group: 'URL指定取得', async: true, confirmation: '指定URLからDAM楽曲を取得します。実行しますか？', inputs: [{ name: :dam_song_url, label: 'DAM楽曲URL', type: :text, placeholder: Constants::Karaoke::Dam::SONG_URL }])
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
            operation('JOYSOUND詳細を取得', handler: :fetch_joysound_detail, group: 'URL指定取得', async: true, confirmation: '指定URLからJOYSOUND詳細を取得します。実行しますか？', inputs: [{ name: :joysound_url, label: 'JOYSOUND URL', type: :text }])
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
            operation('期限切れを削除', handler: :cleanup_expired_joysound_music_posts, group: '検証・削除', async: true, confirmation: '期限切れのミュージックポストを検証し、無効なレコードを削除します。実行しますか？'),
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
end
