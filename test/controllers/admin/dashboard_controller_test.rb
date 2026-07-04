require 'test_helper'

module Admin
  class DashboardControllerTest < ActionDispatch::IntegrationTest
    setup do
      @dam_artist = create_display_artist(karaoke_type: 'DAM')
      @joysound_artist = create_display_artist(karaoke_type: 'JOYSOUND')
      @music_post_artist = create_display_artist(karaoke_type: 'JOYSOUND(うたスキ)')

      @dam_song = create_song(display_artist: @dam_artist, karaoke_type: 'DAM')
      @joysound_song = create_song(display_artist: @joysound_artist, karaoke_type: 'JOYSOUND')
      @music_post_song = create_song(display_artist: @music_post_artist, karaoke_type: 'JOYSOUND(うたスキ)')

      # Song with every distribution URL present, to exercise the FILTER aggregation.
      @fully_linked_song = create_song(
        display_artist: @dam_artist,
        karaoke_type: 'DAM',
        youtube_url: 'https://youtube.example/watch',
        nicovideo_url: 'https://nicovideo.example/watch',
        apple_music_url: 'https://music.apple.example/song',
        youtube_music_url: 'https://music.youtube.example/watch',
        spotify_url: 'https://spotify.example/track',
        line_music_url: 'https://music.line.example/track'
      )

      # Song with explicit empty-string URLs (the DB default), to confirm the boundary
      # between empty string and a present value is handled identically to the scopes.
      @empty_url_song = create_song(
        display_artist: @dam_artist,
        karaoke_type: 'DAM',
        youtube_url: '',
        nicovideo_url: '',
        apple_music_url: '',
        youtube_music_url: '',
        spotify_url: '',
        line_music_url: ''
      )

      original_song = create_original_song
      @linked_song = create_song(display_artist: @dam_artist, karaoke_type: 'DAM')
      @linked_song.original_songs << original_song
    end

    test 'renders successfully' do
      get admin_root_path

      assert_response :success
    end

    test 'distribution metrics match individually computed scope counts' do
      get admin_root_path

      assert_response :success

      total = Song.count
      metrics = distribution_metrics_from_response

      assert_equal Song.dam.count, metrics.fetch('dam').fetch(:value)
      assert_equal Song.joysound.count, metrics.fetch('joysound').fetch(:value)
      assert_equal Song.music_post.count, metrics.fetch('music-post').fetch(:value)
      assert_equal Song.youtube.count, metrics.fetch('youtube').fetch(:value)
      assert_equal Song.where.not(nicovideo_url: '').count, metrics.fetch('nicovideo').fetch(:value)
      assert_equal Song.apple_music.count, metrics.fetch('apple').fetch(:value)
      assert_equal Song.youtube_music.count, metrics.fetch('youtube-music').fetch(:value)
      assert_equal Song.spotify.count, metrics.fetch('spotify').fetch(:value)
      assert_equal Song.line_music.count, metrics.fetch('line-music').fetch(:value)

      metrics.each_value { |metric| assert_equal total, metric.fetch(:total) }
    end

    test 'nicovideo boundary counts exclude empty string urls and include present urls' do
      get admin_root_path

      assert_response :success

      metrics = distribution_metrics_from_response
      assert_equal Song.where.not(nicovideo_url: '').count, metrics.fetch('nicovideo').fetch(:value)
      assert_includes Song.where.not(nicovideo_url: '').pluck(:id), @fully_linked_song.id
      assert_not_includes Song.where.not(nicovideo_url: '').pluck(:id), @empty_url_song.id
    end

    test 'karaoke type distribution is zero for a type with no songs' do
      Song.where(karaoke_type: 'JOYSOUND(うたスキ)').destroy_all

      get admin_root_path

      assert_response :success

      metrics = distribution_metrics_from_response
      assert_equal 0, metrics.fetch('music-post').fetch(:value)
      assert_equal Song.music_post.count, metrics.fetch('music-post').fetch(:value)
    end

    test 'dashboard summary matches individually computed counts' do
      get admin_root_path

      assert_response :success

      summary = controller.send(:dashboard_summary)
      assert_equal Song.count, summary.fetch(:total_songs)
      assert_equal Song.touhou_arrange.count, summary.fetch(:linked_songs)
      assert_equal Song.missing_original_songs.count, summary.fetch(:missing_songs)
      assert_equal OriginalSong.count, summary.fetch(:original_songs)
      assert_equal DisplayArtist.count, summary.fetch(:display_artists)
      assert_equal Circle.count, summary.fetch(:circles)
    end

    test 'insight groups match individually computed counts' do
      get admin_root_path

      assert_response :success

      groups = controller.send(:insight_groups)
      data_status_metrics = groups.find { |group| group[:label] == 'データ状態' }.fetch(:metrics)
      assert_equal Song.count, data_status_metrics.find { |metric| metric[:label] == '総楽曲数' }.fetch(:value)
      assert_equal Song.with_original_songs.count, data_status_metrics.find { |metric| metric[:label] == '原曲紐付け済み' }.fetch(:value)
      assert_equal Song.missing_original_songs.count, data_status_metrics.find { |metric| metric[:label] == '原曲未紐付け' }.fetch(:value)

      master_data_metrics = groups.find { |group| group[:label] == 'マスタデータ' }.fetch(:metrics)
      assert_equal OriginalSong.count, master_data_metrics.find { |metric| metric[:label] == '原曲' }.fetch(:value)
      assert_equal Circle.count, master_data_metrics.find { |metric| metric[:label] == 'サークル' }.fetch(:value)
      assert_equal DisplayArtist.count, master_data_metrics.find { |metric| metric[:label] == 'アーティスト' }.fetch(:value)

      music_post_metrics = groups.find { |group| group[:label] == 'ミュージックポスト' }.fetch(:metrics)
      assert_equal Song.music_post.count, music_post_metrics.find { |metric| metric[:label] == '配信曲' }.fetch(:value)
      assert_equal Song.music_post.with_original_songs.count, music_post_metrics.find { |metric| metric[:label] == '原曲紐付け済み' }.fetch(:value)
    end

    test 'distribution and shared summary counts are issued exactly once per request' do
      sql = capture_sql { get admin_root_path }

      assert_response :success

      # distribution_metrics: karaoke_type breakdown consolidated into a single GROUP BY.
      group_by_karaoke_type = sql.select { |statement| statement.include?('GROUP BY "songs"."karaoke_type"') }
      assert_equal 1, group_by_karaoke_type.size, "expected a single karaoke_type GROUP BY query, got: #{group_by_karaoke_type}"

      # distribution_metrics: total + per-service FILTER counts consolidated into one query.
      filter_aggregate = sql.select { |statement| statement.include?('COUNT(*) FILTER') }
      assert_equal 1, filter_aggregate.size, "expected a single FILTER aggregate query, got: #{filter_aggregate}"
      assert_includes filter_aggregate.first, "COUNT(*) FILTER (WHERE youtube_url <> '')"
      assert_includes filter_aggregate.first, "COUNT(*) FILTER (WHERE nicovideo_url <> '')"
      assert_includes filter_aggregate.first, "COUNT(*) FILTER (WHERE apple_music_url <> '')"
      assert_includes filter_aggregate.first, "COUNT(*) FILTER (WHERE youtube_music_url <> '')"
      assert_includes filter_aggregate.first, "COUNT(*) FILTER (WHERE spotify_url <> '')"
      assert_includes filter_aggregate.first, "COUNT(*) FILTER (WHERE line_music_url <> '')"

      # dashboard_summary / insight_groups share the same memoized counts, so each of these
      # should be issued only once despite being referenced from two different methods.
      missing_original_songs_queries = sql.select { |statement| statement.include?('"songs_original_songs"."id" IS NULL') }
      assert_equal 1, missing_original_songs_queries.size, "expected missing_original_songs to be memoized, got: #{missing_original_songs_queries}"
    end

    test 'dashboard counts are served from cache on subsequent requests' do
      with_cache_store(ActiveSupport::Cache::MemoryStore.new) do
        first_sql = capture_sql { get admin_root_path }
        assert_response :success

        # 初回リクエストで集計クエリが発行され、キャッシュへ書き込まれる。
        assert_equal 1, count_matching(first_sql, 'GROUP BY "songs"."karaoke_type"')
        assert_equal 1, count_matching(first_sql, 'COUNT(*) FILTER')

        second_sql = capture_sql { get admin_root_path }
        assert_response :success

        # 2回目はキャッシュヒットのため COUNT 系集計クエリが再発行されない。
        assert_equal 0, count_matching(second_sql, 'GROUP BY "songs"."karaoke_type"')
        assert_equal 0, count_matching(second_sql, 'COUNT(*) FILTER')
      end
    end

    test 'cached counts match individually computed values' do
      with_cache_store(ActiveSupport::Cache::MemoryStore.new) do
        get admin_root_path
        assert_response :success

        cached = Rails.cache.fetch('admin:dashboard:v1')
        assert_equal Song.count, cached.fetch(:total_songs)
        assert_equal Song.touhou_arrange.count, cached.fetch(:linked_songs)
        assert_equal Song.missing_original_songs.count, cached.fetch(:missing_original_songs)
        assert_equal Song.with_original_songs.count, cached.fetch(:with_original_songs)
        assert_equal Song.music_post.with_original_songs.count, cached.fetch(:music_post_with_original_songs)
        assert_equal OriginalSong.count, cached.fetch(:original_songs)
        assert_equal DisplayArtist.count, cached.fetch(:display_artists)
        assert_equal Circle.count, cached.fetch(:circles)
        assert_equal Original.count, cached.fetch(:originals)
        assert_equal KaraokeDeliveryModel.count, cached.fetch(:karaoke_delivery_models)
        assert_equal JoysoundMusicPost.count, cached.fetch(:joysound_music_posts)
        assert_equal Song.count, cached.fetch(:distribution_service_counts).fetch(:total)
        assert_equal Song.youtube.count, cached.fetch(:distribution_service_counts).fetch(:youtube)
        assert_equal Song.group(:karaoke_type).count, cached.fetch(:karaoke_type_counts)
      end
    end

    private

    def count_matching(statements, fragment)
      statements.count { |statement| statement.include?(fragment) }
    end

    def with_cache_store(store)
      original = Rails.cache
      Rails.cache = store
      yield
    ensure
      store.clear
      Rails.cache = original
    end

    def distribution_metrics_from_response
      controller.send(:distribution_metrics).index_by { |metric| metric.fetch(:key) }
    end

    def capture_sql
      statements = []
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
        payload = args.last
        next if payload[:name].in?(%w[SCHEMA TRANSACTION])

        statements << payload[:sql].squish
      end
      yield
      statements
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end
  end
end
