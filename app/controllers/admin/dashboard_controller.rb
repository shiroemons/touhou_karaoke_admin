module Admin
  class DashboardController < BaseController
    def show
      @resources = admin_resources
      @management_groups = management_groups
      @dashboard_summary = dashboard_summary
      @distribution_groups = distribution_groups
      @quick_operation_groups = quick_operation_groups
      @insight_groups = insight_groups
    end

    private

    # 全スカラー集計を per-request メモ化 + cross-request 低レベルキャッシュの
    # 二重構造で取得する。@dashboard_counts のメモ化により、1リクエスト内では
    # cache.fetch は1回だけ呼ばれる (test 環境の :null_store でも計算は1回で済む)。
    def dashboard_counts
      @dashboard_counts ||= Rails.cache.fetch('admin:dashboard:v1', expires_in: 5.minutes) { compute_dashboard_counts }
    end

    # キャッシュに格納するのはプリミティブ値 (整数・文字列) と、それらの Hash/配列のみ。
    # ResourceRegistry::Resource のような Data オブジェクトは Marshal 化できないため含めない。
    def compute_dashboard_counts
      service_counts = distribution_service_counts

      {
        karaoke_type_counts: Song.group(:karaoke_type).count,
        distribution_service_counts: service_counts,
        total_songs: service_counts[:total],
        linked_songs: Song.touhou_arrange.count,
        missing_original_songs: Song.missing_original_songs.count,
        with_original_songs: Song.with_original_songs.count,
        music_post_with_original_songs: Song.music_post.with_original_songs.count,
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

    # 総楽曲数と各配信サービスの有無カウントを FILTER 句でまとめて1クエリで取得し、
    # プリミティブな Hash に変換する。各 FILTER 条件は Song モデルの
    # youtube/apple_music/youtube_music/spotify/line_music スコープ (where.not(col: ""))
    # およびニコニコ動画の where.not(nicovideo_url: "") と完全に一致させている。
    def distribution_service_counts
      row = Song.select(
        'COUNT(*) AS total',
        "COUNT(*) FILTER (WHERE youtube_url <> '') AS youtube_count",
        "COUNT(*) FILTER (WHERE nicovideo_url <> '') AS nicovideo_count",
        "COUNT(*) FILTER (WHERE apple_music_url <> '') AS apple_music_count",
        "COUNT(*) FILTER (WHERE youtube_music_url <> '') AS youtube_music_count",
        "COUNT(*) FILTER (WHERE spotify_url <> '') AS spotify_count",
        "COUNT(*) FILTER (WHERE line_music_url <> '') AS line_music_count"
      ).take

      {
        total: row.total.to_i,
        youtube: row.youtube_count.to_i,
        nicovideo: row.nicovideo_count.to_i,
        apple_music: row.apple_music_count.to_i,
        youtube_music: row.youtube_music_count.to_i,
        spotify: row.spotify_count.to_i,
        line_music: row.line_music_count.to_i
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

    def distribution_groups
      metrics = distribution_metrics
      [
        { label: '配信種別', metrics: metrics.first(3) },
        { label: '動画', metrics: metrics.slice(3, 2) },
        { label: '音楽配信', metrics: metrics.drop(5) }
      ]
    end

    def distribution_metrics
      counts = dashboard_counts
      by_type = counts[:karaoke_type_counts]
      service_counts = counts[:distribution_service_counts]
      total = service_counts[:total]

      [
        distribution_metric('DAM', by_type.fetch('DAM', 0), total, 'dam'),
        distribution_metric('JOYSOUND', by_type.fetch('JOYSOUND', 0), total, 'joysound'),
        distribution_metric('ミュージックポスト', by_type.fetch('JOYSOUND(うたスキ)', 0), total, 'music-post'),
        distribution_metric('YouTube', service_counts[:youtube], total, 'youtube'),
        distribution_metric('ニコニコ動画', service_counts[:nicovideo], total, 'nicovideo'),
        distribution_metric('Apple Music', service_counts[:apple_music], total, 'apple'),
        distribution_metric('YouTube Music', service_counts[:youtube_music], total, 'youtube-music'),
        distribution_metric('Spotify', service_counts[:spotify], total, 'spotify'),
        distribution_metric('LINE MUSIC', service_counts[:line_music], total, 'line-music')
      ]
    end

    def distribution_metric(label, value, total, key)
      { label:, value:, total:, key:, percentage: percentage(value, total) }
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
        '作品マスタ' => :original_song,
        '配信管理' => :song,
        'DAM' => :dam_song,
        'JOYSOUND' => :joysound_song
      }[label]
    end

    def management_group_description(label)
      {
        '作品マスタ' => '原作と原曲の基礎データ',
        '配信管理' => '配信曲を中心にアーティスト・サークル・機種を管理',
        'DAM' => 'DAMの取得データとアーティストURL',
        'JOYSOUND' => 'JOYSOUND楽曲とミュージックポスト'
      }.fetch(label, '補助データ')
    end

    def management_group_icon(label)
      {
        '作品マスタ' => :original_songs,
        '配信管理' => :songs,
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
