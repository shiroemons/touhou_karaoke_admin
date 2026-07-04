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

    def dashboard_summary
      total = total_songs
      linked_songs = Song.touhou_arrange.count
      missing_songs = missing_original_songs_count

      {
        total_songs: total,
        linked_songs:,
        missing_songs:,
        linked_rate: percentage(linked_songs, total),
        original_songs: original_songs_count,
        display_artists: display_artists_count,
        circles: circles_count
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
      by_type = karaoke_type_counts
      service_counts = distribution_service_counts
      total = service_counts.total

      [
        distribution_metric('DAM', by_type.fetch('DAM', 0), total, 'dam'),
        distribution_metric('JOYSOUND', by_type.fetch('JOYSOUND', 0), total, 'joysound'),
        distribution_metric('ミュージックポスト', by_type.fetch('JOYSOUND(うたスキ)', 0), total, 'music-post'),
        distribution_metric('YouTube', service_counts.youtube_count, total, 'youtube'),
        distribution_metric('ニコニコ動画', service_counts.nicovideo_count, total, 'nicovideo'),
        distribution_metric('Apple Music', service_counts.apple_music_count, total, 'apple'),
        distribution_metric('YouTube Music', service_counts.youtube_music_count, total, 'youtube-music'),
        distribution_metric('Spotify', service_counts.spotify_count, total, 'spotify'),
        distribution_metric('LINE MUSIC', service_counts.line_music_count, total, 'line-music')
      ]
    end

    def distribution_metric(label, value, total, key)
      { label:, value:, total:, key:, percentage: percentage(value, total) }
    end

    # 種別分布 (DAM / JOYSOUND / ミュージックポスト) を1クエリで取得する。
    def karaoke_type_counts
      @karaoke_type_counts ||= Song.group(:karaoke_type).count
    end

    # 総楽曲数と各配信サービスの有無カウントを FILTER 句でまとめて1クエリで取得する。
    # 各 FILTER 条件は Song モデルの youtube/apple_music/youtube_music/spotify/line_music
    # スコープ (where.not(col: "")) およびニコニコ動画の where.not(nicovideo_url: "") と
    # 完全に一致させている。
    def distribution_service_counts
      @distribution_service_counts ||= Song.select(
        'COUNT(*) AS total',
        "COUNT(*) FILTER (WHERE youtube_url <> '') AS youtube_count",
        "COUNT(*) FILTER (WHERE nicovideo_url <> '') AS nicovideo_count",
        "COUNT(*) FILTER (WHERE apple_music_url <> '') AS apple_music_count",
        "COUNT(*) FILTER (WHERE youtube_music_url <> '') AS youtube_music_count",
        "COUNT(*) FILTER (WHERE spotify_url <> '') AS spotify_count",
        "COUNT(*) FILTER (WHERE line_music_url <> '') AS line_music_count"
      ).take
    end

    # dashboard_summary と insight_groups で共有する母数。同一リクエスト内での重複発行を避ける。
    def total_songs
      @total_songs ||= distribution_service_counts.total
    end

    def missing_original_songs_count
      @missing_original_songs_count ||= Song.missing_original_songs.count
    end

    def original_songs_count
      @original_songs_count ||= OriginalSong.count
    end

    def display_artists_count
      @display_artists_count ||= DisplayArtist.count
    end

    def circles_count
      @circles_count ||= Circle.count
    end

    def management_groups
      ResourceRegistry.navigation_groups.map do |label, resources|
        items = resources.map { |resource| { resource:, count: resource.model.count } }
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
      [
        {
          label: 'データ状態',
          description: '楽曲と原曲の紐付け状況',
          metrics: [
            metric('総楽曲数', total_songs, '曲', admin_songs_path),
            metric('原曲紐付け済み', Song.with_original_songs.count, '曲', admin_songs_path(filters: { original_link: 'linked' })),
            metric('原曲未紐付け', missing_original_songs_count, '曲', admin_songs_path(filters: { original_link: 'missing' }))
          ]
        },
        {
          label: 'マスタデータ',
          description: '検索・紐付けに使う基礎データ',
          metrics: [
            metric('原作', Original.count, '件', admin_originals_path),
            metric('原曲', original_songs_count, '曲', admin_original_songs_path),
            metric('サークル', circles_count, '件', admin_circles_path),
            metric('アーティスト', display_artists_count, '件', admin_display_artists_path),
            metric('配信機種', KaraokeDeliveryModel.count, '件', admin_karaoke_delivery_models_path)
          ]
        },
        {
          label: 'ミュージックポスト',
          description: '取得済みデータと配信期限',
          metrics: [
            metric('配信曲', karaoke_type_counts.fetch('JOYSOUND(うたスキ)', 0), '曲', admin_songs_path(filters: { karaoke_type: 'joysound_music_post' })),
            metric('原曲紐付け済み', Song.music_post.with_original_songs.count, '曲', admin_songs_path(filters: { karaoke_type: 'joysound_music_post', original_link: 'linked' })),
            metric('取得済み', JoysoundMusicPost.count, '件', admin_joysound_music_posts_path),
            metric('期限内', JoysoundMusicPost.where(delivery_deadline_on: Date.current..).count, '件', admin_joysound_music_posts_path(filters: { delivery_deadline_on: 'active' })),
            metric('期限切れ', JoysoundMusicPost.where(delivery_deadline_on: ...Date.current).count, '件', admin_joysound_music_posts_path(filters: { delivery_deadline_on: 'expired' }))
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
