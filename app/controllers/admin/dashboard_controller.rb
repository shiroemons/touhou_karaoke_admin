module Admin
  class DashboardController < BaseController
    def show
      @resources = admin_resources
      @management_groups = management_groups
      @dashboard_summary = dashboard_summary
      @priority_metrics = priority_metrics
      @delivery_type_metrics = delivery_type_metrics
      @delivery_type_chart = delivery_type_chart
      @quick_operation_groups = quick_operation_groups
      @insight_groups = insight_groups
    end

    private

    # 全スカラー集計を per-request メモ化 + cross-request 低レベルキャッシュの
    # 二重構造で取得する。@dashboard_counts のメモ化により、1リクエスト内では
    # cache.fetch は1回だけ呼ばれる (test 環境の :null_store でも計算は1回で済む)。
    def dashboard_counts
      @dashboard_counts ||= Rails.cache.fetch('admin:dashboard:v2', expires_in: 5.minutes) { compute_dashboard_counts }
    end

    # キャッシュに格納するのはプリミティブ値 (整数・文字列) と、それらの Hash/配列のみ。
    # ResourceRegistry::Resource のような Data オブジェクトは Marshal 化できないため含めない。
    def compute_dashboard_counts
      linked_songs = Song.with_original_songs.count

      {
        karaoke_type_counts: Song.group(:karaoke_type).count,
        total_songs: Song.count,
        linked_songs:,
        missing_original_songs: Song.missing_original_songs.count,
        with_original_songs: linked_songs,
        music_post_with_original_songs: Song.music_post.with_original_songs.count,
        music_post_missing_original_songs: Song.music_post.missing_original_songs.count,
        original_songs: OriginalSong.count,
        display_artists: DisplayArtist.count,
        circles: Circle.count,
        originals: Original.count,
        karaoke_delivery_models: KaraokeDeliveryModel.count,
        joysound_music_posts: JoysoundMusicPost.count,
        music_posts_active: JoysoundMusicPost.where(delivery_deadline_on: Date.current..).count,
        music_posts_expired: JoysoundMusicPost.where(delivery_deadline_on: ...Date.current).count,
        management_counts: management_counts
      }
    end

    # navigation_groups の全リソースについて { resource.key => count } を1つの Hash にまとめる。
    # navigation_groups はキーを index_by してから delete するためリソースキーは全体で一意。
    def management_counts
      ResourceRegistry.navigation_groups.each_with_object({}) do |(_label, resources), counts|
        resources.each { |resource| counts[resource.key] = resource.model.count }
      end
    end

    def dashboard_summary
      counts = dashboard_counts
      total = counts[:total_songs]
      linked_songs = counts[:linked_songs]

      {
        total_songs: total,
        linked_songs:,
        missing_songs: counts[:missing_original_songs],
        linked_rate: percentage(linked_songs, total),
        original_songs: counts[:original_songs],
        display_artists: counts[:display_artists],
        circles: counts[:circles]
      }
    end

    def delivery_type_metrics
      counts = dashboard_counts
      by_type = counts[:karaoke_type_counts]
      total = counts[:total_songs]

      [
        delivery_type_metric('DAM', by_type.fetch('DAM', 0), total, 'dam'),
        delivery_type_metric('JOYSOUND', by_type.fetch('JOYSOUND', 0), total, 'joysound'),
        delivery_type_metric('ミュージックポスト', by_type.fetch('JOYSOUND(うたスキ)', 0), total, 'music-post')
      ]
    end

    def delivery_type_metric(label, value, total, key)
      { label:, value:, total:, key:, percentage: percentage(value, total) }
    end

    def priority_metrics
      counts = dashboard_counts

      [
        priority_metric(
          label: '原曲未紐付け',
          value: counts[:missing_original_songs],
          unit: '曲',
          description: '原曲を確認して紐付ける対象',
          path: admin_songs_path(filters: { original_link: 'missing' }),
          tone: :warning
        ),
        priority_metric(
          label: '期限切れ',
          value: counts[:music_posts_expired],
          unit: '件',
          description: 'ミュージックポスト側で確認する対象',
          path: admin_joysound_music_posts_path(filters: { delivery_deadline_on: 'expired' }),
          tone: :danger
        ),
        priority_metric(
          label: 'MP原曲未紐付け',
          value: counts[:music_post_missing_original_songs],
          unit: '曲',
          description: 'ミュージックポスト配信曲の紐付け待ち',
          path: admin_songs_path(filters: { karaoke_type: 'joysound_music_post', original_link: 'missing' }),
          tone: :info
        )
      ]
    end

    def priority_metric(attributes)
      attributes
    end

    def delivery_type_chart
      metrics = delivery_type_metrics
      dam_percentage = metrics.find { |metric| metric[:key] == 'dam' }.fetch(:percentage)
      joysound_percentage = metrics.find { |metric| metric[:key] == 'joysound' }.fetch(:percentage)

      {
        dam_end: dam_percentage,
        joysound_end: dam_percentage + joysound_percentage,
        metrics:
      }
    end

    def management_groups
      counts = dashboard_counts[:management_counts]

      ResourceRegistry.navigation_groups.map do |label, resources|
        items = resources.map { |resource| { resource:, count: counts.fetch(resource.key) } }
        primary = resources.find { |resource| resource.key == primary_management_resource_key(label) } || resources.first

        {
          label:,
          description: management_group_description(label),
          icon: management_group_icon(label),
          primary:,
          items:,
          total_count: items.sum { |item| item[:count] }
        }
      end
    end

    def primary_management_resource_key(label)
      {
        'メイン' => :song,
        '作品マスタ' => :original_song,
        '配信管理' => :display_artist,
        'DAM' => :dam_song,
        'JOYSOUND' => :joysound_song
      }[label]
    end

    def management_group_description(label)
      {
        'メイン' => '日々確認する配信曲データ',
        '作品マスタ' => '原作と原曲の基礎データ',
        '配信管理' => 'アーティスト・サークル・配信機種を管理',
        'DAM' => 'DAMの取得データとアーティストURL',
        'JOYSOUND' => 'JOYSOUND楽曲とミュージックポスト'
      }.fetch(label, '補助データ')
    end

    def management_group_icon(label)
      {
        'メイン' => :songs,
        '作品マスタ' => :original_songs,
        '配信管理' => :display_artists,
        'DAM' => :dam_songs,
        'JOYSOUND' => :joysound_songs
      }.fetch(label, :dashboard)
    end

    def quick_operation_groups
      [
        quick_operation_group('取得・更新', [
                                %i[song fetch_dam_songs],
                                %i[song fetch_joysound_songs],
                                %i[song fetch_joysound_music_post_song]
                              ]),
        quick_operation_group('検証・整理', [
                                %i[display_artist validate_display_artist_urls],
                                %i[display_artist cleanup_orphan_display_artists],
                                %i[joysound_music_post cleanup_expired_joysound_music_posts]
                              ]),
        quick_operation_group('TSV', [
                                %i[song export_songs],
                                %i[song export_missing_original_songs],
                                %i[song import_songs_with_original_songs]
                              ])
      ]
    end

    def quick_operation_group(label, operation_specs)
      operations = operation_specs.filter_map do |resource_key, operation_key|
        resource = ResourceRegistry.fetch(resource_key)
        operation = resource.operations.find { |item| item.key == operation_key.to_s || item.handler == operation_key || item.method_name == operation_key }
        { resource:, operation: } if operation
      end

      { label:, operations: }
    end

    def insight_groups
      counts = dashboard_counts

      [
        {
          label: 'データ状態',
          description: '楽曲と原曲の紐付け状況',
          metrics: [
            metric('総楽曲数', counts[:total_songs], '曲', admin_songs_path),
            metric('原曲紐付け済み', counts[:with_original_songs], '曲', admin_songs_path(filters: { original_link: 'linked' })),
            metric('原曲未紐付け', counts[:missing_original_songs], '曲', admin_songs_path(filters: { original_link: 'missing' }))
          ]
        },
        {
          label: 'マスタデータ',
          description: '検索・紐付けに使う基礎データ',
          metrics: [
            metric('原作', counts[:originals], '件', admin_originals_path),
            metric('原曲', counts[:original_songs], '曲', admin_original_songs_path),
            metric('サークル', counts[:circles], '件', admin_circles_path),
            metric('アーティスト', counts[:display_artists], '件', admin_display_artists_path),
            metric('配信機種', counts[:karaoke_delivery_models], '件', admin_karaoke_delivery_models_path)
          ]
        },
        {
          label: 'ミュージックポスト',
          description: '取得済みデータと配信期限',
          metrics: [
            metric('配信曲', counts[:karaoke_type_counts].fetch('JOYSOUND(うたスキ)', 0), '曲', admin_songs_path(filters: { karaoke_type: 'joysound_music_post' })),
            metric('原曲紐付け済み', counts[:music_post_with_original_songs], '曲', admin_songs_path(filters: { karaoke_type: 'joysound_music_post', original_link: 'linked' })),
            metric('原曲未紐付け', counts[:music_post_missing_original_songs], '曲', admin_songs_path(filters: { karaoke_type: 'joysound_music_post', original_link: 'missing' })),
            metric('取得済み', counts[:joysound_music_posts], '件', admin_joysound_music_posts_path),
            metric('期限内', counts[:music_posts_active], '件', admin_joysound_music_posts_path(filters: { delivery_deadline_on: 'active' })),
            metric('期限切れ', counts[:music_posts_expired], '件', admin_joysound_music_posts_path(filters: { delivery_deadline_on: 'expired' }))
          ]
        }
      ]
    end

    def metric(label, value, unit, path)
      { label:, value:, unit:, path: }
    end

    def percentage(value, total)
      return 0 if total.to_i.zero?

      ((value.to_f / total) * 100).round
    end
  end
end
