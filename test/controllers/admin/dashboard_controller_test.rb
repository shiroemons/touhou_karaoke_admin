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
      assert_select '.admin-dashboard-freshness time[datetime]'
      assert_select 'form[action=?][method="post"] button[aria-label="ダッシュボードを再集計"]', admin_dashboard_refresh_path, text: '再集計'
    end

    test 'dashboard insight headings have unique accessible ids' do
      get admin_root_path

      assert_response :success

      heading_ids = css_select('.admin-dashboard-insight-group[aria-labelledby]').pluck('aria-labelledby')
      assert_equal heading_ids.length, heading_ids.uniq.length
      heading_ids.each { |heading_id| assert_select "##{heading_id}", 1 }
    end

    test 'delivery type metrics match individually computed scope counts' do
      get admin_root_path

      assert_response :success

      total = Song.count
      metrics = delivery_type_metrics_from_response

      assert_equal Song.dam.count, metrics.fetch('dam').fetch(:value)
      assert_equal Song.joysound.count, metrics.fetch('joysound').fetch(:value)
      assert_equal Song.music_post.count, metrics.fetch('music-post').fetch(:value)

      metrics.each_value { |metric| assert_equal total, metric.fetch(:total) }
    end

    test 'priority metrics link to actionable filtered admin pages' do
      get admin_root_path

      assert_response :success

      metrics = controller.send(:priority_metrics).index_by { |metric| metric.fetch(:label) }
      assert_equal Song.missing_original_songs.count, metrics.fetch('原曲未紐付け').fetch(:value)
      assert_equal admin_songs_path(filters: { original_link: 'missing' }), metrics.fetch('原曲未紐付け').fetch(:path)
      assert_equal JoysoundMusicPost.where(delivery_deadline_on: ...Date.current).count, metrics.fetch('期限切れ').fetch(:value)
      assert_equal admin_joysound_music_posts_path(filters: { delivery_deadline_on: 'expired' }), metrics.fetch('期限切れ').fetch(:path)
      assert_equal Song.music_post.missing_original_songs.count, metrics.fetch('MP原曲未紐付け').fetch(:value)
      assert_equal admin_songs_path(filters: { karaoke_type: 'joysound_music_post', original_link: 'missing' }), metrics.fetch('MP原曲未紐付け').fetch(:path)
    end

    test 'karaoke type distribution is zero for a type with no songs' do
      Song.where(karaoke_type: 'JOYSOUND(うたスキ)').destroy_all

      get admin_root_path

      assert_response :success

      metrics = delivery_type_metrics_from_response
      assert_equal 0, metrics.fetch('music-post').fetch(:value)
      assert_equal Song.music_post.count, metrics.fetch('music-post').fetch(:value)
    end

    test 'dashboard summary matches individually computed counts' do
      get admin_root_path

      assert_response :success

      summary = controller.send(:dashboard_summary)
      assert_equal Song.count, summary.fetch(:total_songs)
      assert_equal Song.with_original_songs.count, summary.fetch(:linked_songs)
      assert_equal Song.missing_original_songs.count, summary.fetch(:missing_songs)
      assert_equal OriginalSong.count, summary.fetch(:original_songs)
      assert_equal DisplayArtist.count, summary.fetch(:display_artists)
      assert_equal Circle.count, summary.fetch(:circles)
    end

    test 'dashboard linked metric includes original and other categories' do
      original_category_song = create_song(display_artist: @dam_artist, karaoke_type: 'DAM')
      original_category_song.original_songs << create_original_song(title: 'オリジナル')

      get admin_root_path

      assert_response :success

      summary = controller.send(:dashboard_summary)
      assert_not_includes Song.touhou_arrange.pluck(:id), original_category_song.id
      assert_equal Song.with_original_songs.count, summary.fetch(:linked_songs)
      assert_equal summary.fetch(:linked_songs), summary.fetch(:total_songs) - summary.fetch(:missing_songs)
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
      assert_equal Song.music_post.missing_original_songs.count, music_post_metrics.find { |metric| metric[:label] == '原曲未紐付け' }.fetch(:value)
    end

    test 'delivery type and shared summary counts are memoized per request' do
      sql = capture_sql { get admin_root_path }

      assert_response :success

      # delivery_type_metrics: karaoke_type breakdown consolidated into a single GROUP BY.
      group_by_karaoke_type = sql.select { |statement| statement.include?('GROUP BY "songs"."karaoke_type"') }
      assert_equal 1, group_by_karaoke_type.size, "expected a single karaoke_type GROUP BY query, got: #{group_by_karaoke_type}"

      # dashboard_summary / insight_groups share the same memoized counts, so each of these
      # should be issued only once despite being referenced from two different methods.
      missing_original_songs_queries = sql.select { |statement| statement.include?('"songs_original_songs"."id" IS NULL') }
      assert_equal 2, missing_original_songs_queries.size, "expected missing original song counts to be memoized, got: #{missing_original_songs_queries}"
    end

    test 'dashboard counts are served from cache on subsequent requests' do
      with_cache_store(ActiveSupport::Cache::MemoryStore.new) do
        first_sql = capture_sql { get admin_root_path }
        assert_response :success

        # 初回リクエストで集計クエリが発行され、キャッシュへ書き込まれる。
        assert_equal 1, count_matching(first_sql, 'GROUP BY "songs"."karaoke_type"')
        assert_operator count_matching(first_sql, 'COUNT(*)'), :positive?

        second_sql = capture_sql { get admin_root_path }
        assert_response :success

        # 2回目はキャッシュヒットのため COUNT 系集計クエリが再発行されない。
        assert_equal 0, count_matching(second_sql, 'GROUP BY "songs"."karaoke_type"')
        assert_equal 0, count_matching(second_sql, 'COUNT(*)')
      end
    end

    test 'dashboard refresh clears the cached counts before the next request' do
      with_cache_store(ActiveSupport::Cache::MemoryStore.new) do
        get admin_root_path
        assert_response :success
        assert Rails.cache.exist?(DashboardController::DASHBOARD_CACHE_KEY)

        post admin_dashboard_refresh_path

        assert_redirected_to admin_root_path
        assert_equal I18n.t('admin.dashboard_refreshed'), flash[:notice]
        assert_not Rails.cache.exist?(DashboardController::DASHBOARD_CACHE_KEY)

        get admin_root_path
        assert_response :success
        assert Rails.cache.exist?(DashboardController::DASHBOARD_CACHE_KEY)
        assert_equal Song.count, controller.send(:dashboard_summary).fetch(:total_songs)
      end
    end

    test 'cached counts match individually computed values' do
      with_cache_store(ActiveSupport::Cache::MemoryStore.new) do
        get admin_root_path
        assert_response :success

        cached = Rails.cache.fetch(DashboardController::DASHBOARD_CACHE_KEY)
        assert_equal Song.count, cached.fetch(:total_songs)
        assert_equal Song.with_original_songs.count, cached.fetch(:linked_songs)
        assert_equal Song.missing_original_songs.count, cached.fetch(:missing_original_songs)
        assert_equal Song.with_original_songs.count, cached.fetch(:with_original_songs)
        assert_equal Song.music_post.with_original_songs.count, cached.fetch(:music_post_with_original_songs)
        assert_equal OriginalSong.count, cached.fetch(:original_songs)
        assert_equal DisplayArtist.count, cached.fetch(:display_artists)
        assert_equal Circle.count, cached.fetch(:circles)
        assert_equal Original.count, cached.fetch(:originals)
        assert_equal KaraokeDeliveryModel.count, cached.fetch(:karaoke_delivery_models)
        assert_equal JoysoundMusicPost.count, cached.fetch(:joysound_music_posts)
        assert_equal Song.music_post.missing_original_songs.count, cached.fetch(:music_post_missing_original_songs)
        assert_equal Song.group(:karaoke_type).count, cached.fetch(:karaoke_type_counts)
        assert_match(/\A\d{4}-\d{2}-\d{2}T/, cached.fetch(:generated_at))
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

    def delivery_type_metrics_from_response
      controller.send(:delivery_type_metrics).index_by { |metric| metric.fetch(:key) }
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
