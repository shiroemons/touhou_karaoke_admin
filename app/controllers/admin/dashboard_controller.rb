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
      total_songs = Song.count
      linked_songs = Song.touhou_arrange.count
      missing_songs = Song.missing_original_songs.count

      {
        total_songs:,
        linked_songs:,
        missing_songs:,
        linked_rate: percentage(linked_songs, total_songs),
        original_songs: OriginalSong.count,
        display_artists: DisplayArtist.count,
        circles: Circle.count
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
      [
        distribution_metric('DAM', Song.dam.count, Song.count, 'dam'),
        distribution_metric('JOYSOUND', Song.joysound.count, Song.count, 'joysound'),
        distribution_metric('ミュージックポスト', Song.music_post.count, Song.count, 'music-post'),
        distribution_metric('YouTube', Song.youtube.count, Song.count, 'youtube'),
        distribution_metric('ニコニコ動画', Song.where.not(nicovideo_url: '').count, Song.count, 'nicovideo'),
        distribution_metric('Apple Music', Song.apple_music.count, Song.count, 'apple'),
        distribution_metric('YouTube Music', Song.youtube_music.count, Song.count, 'youtube-music'),
        distribution_metric('Spotify', Song.spotify.count, Song.count, 'spotify'),
        distribution_metric('LINE MUSIC', Song.line_music.count, Song.count, 'line-music')
      ]
    end

    def distribution_metric(label, value, total, key)
      { label:, value:, total:, key:, percentage: percentage(value, total) }
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
            metric('総楽曲数', Song.count, '曲', admin_songs_path),
            metric('原曲紐付け済み', Song.touhou_arrange.count, '曲', admin_songs_path),
            metric('原曲未紐付け', Song.missing_original_songs.count, '曲', admin_songs_path(filters: { original_songs: 'missing_original_songs' }))
          ]
        },
        {
          label: 'マスタデータ',
          description: '検索・紐付けに使う基礎データ',
          metrics: [
            metric('原作', Original.count, '件', admin_originals_path),
            metric('原曲', OriginalSong.count, '曲', admin_original_songs_path),
            metric('サークル', Circle.count, '件', admin_circles_path),
            metric('アーティスト', DisplayArtist.count, '件', admin_display_artists_path),
            metric('配信機種', KaraokeDeliveryModel.count, '件', admin_karaoke_delivery_models_path)
          ]
        },
        {
          label: 'ミュージックポスト',
          description: '取得済みデータと配信期限',
          metrics: [
            metric('配信曲', Song.music_post.count, '曲', admin_songs_path(filters: { karaoke_type: 'joysound_music_post' })),
            metric('原曲紐付け済み', Song.music_post.touhou_arrange.count, '曲', admin_songs_path(filters: { karaoke_type: 'joysound_music_post' })),
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
