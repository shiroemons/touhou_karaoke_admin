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
      'cleanup_orphan_display_artists' => '楽曲が1件も紐づいていないアーティストを削除します。必要に応じて削除対象をTSVで出力できます。',
      'fetch_dam_touhou_songs' => <<~TEXT,
        DAMの東方系検索結果を巡回し、DAM楽曲一覧とDAMアーティストURLを登録・更新します。カラオケ楽曲への本登録は別操作の「DAM候補をカラオケ楽曲へ登録」で行います。

        取得元URL:
        #{Constants::Karaoke::Dam::SEARCH_URL}1
      TEXT
      'fetch_dam_song' => <<~TEXT,
        入力されたDAM楽曲URLから、曲名とアーティスト情報を取得し、DAM候補一覧へ1件登録・更新します。カラオケ楽曲への本登録は別操作の「DAM候補をカラオケ楽曲へ登録」で行います。

        入力URLの形式:
        #{Constants::Karaoke::Dam::SONG_URL}
      TEXT
      'fetch_joysound_detail' => <<~TEXT,
        入力されたJOYSOUND楽曲URLから、表示タイトルを取得してJOYSOUND候補一覧へ1件登録・更新します。詳細なカラオケ楽曲登録は「JOYSOUND候補をカラオケ楽曲へ登録」で行います。

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
      include ResourceRegistryDefinitions

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
    end
  end
end
