# frozen_string_literal: true

module Admin
  class WorkflowDefinition
    Step = Data.define(:key, :resource_key, :operation_key, :note, :cadence, :kind, :numbered)
    Branch = Data.define(:key, :label, :steps)
    Stage = Data.define(:key, :label, :parallel, :branches)
    Definition = Data.define(:key, :label, :description, :icon, :stages, :metrics)

    class << self
      def all
        definitions.index_by(&:key)
      end

      def fetch(key)
        all.fetch(key.to_s)
      end

      def listed
        definitions.reject { |definition| definition.key == 'full' }
      end

      def definitions
        [
          full_workflow,
          music_post_workflow,
          joysound_workflow,
          dam_workflow,
          common_workflow
        ]
      end

      private

      def full_workflow
        Definition.new(
          key: 'full',
          label: '全体更新',
          description: 'JOYSOUND(うたスキ)を先に処理し、その後JOYSOUNDとDAMを並列実行します。',
          icon: :workflow,
          stages: [
            Stage.new(key: 'music_post', label: 'JOYSOUND(うたスキ)', parallel: false, branches: [music_post_branch]),
            Stage.new(key: 'karaoke', label: 'JOYSOUND / DAM', parallel: true, branches: [joysound_branch, dam_branch])
          ],
          metrics: []
        )
      end

      def music_post_workflow
        Definition.new(
          key: 'music_post',
          label: 'JOYSOUND(うたスキ)',
          description: 'ミュージックポストの取得、URL紐付け、カラオケ楽曲登録、期限確認をまとめます。',
          icon: :joysound_music_posts,
          stages: [Stage.new(key: 'music_post', label: 'JOYSOUND(うたスキ)', parallel: false, branches: [music_post_branch])],
          metrics: [
            metric('取得済み', JoysoundMusicPost.count, '件', :admin_joysound_music_posts_path),
            metric('配信曲', Song.music_post.count, '曲', :admin_songs_path, filters: { karaoke_type: 'joysound_music_post' }),
            metric('期限切れ', JoysoundMusicPost.where(delivery_deadline_on: ...Date.current).count, '件', :admin_joysound_music_posts_path, filters: { delivery_deadline_on: 'expired' })
          ]
        )
      end

      def joysound_workflow
        Definition.new(
          key: 'joysound',
          label: 'JOYSOUND',
          description: '候補一覧を作り、カラオケ楽曲登録後にアーティスト読みを補完します。',
          icon: :joysound_songs,
          stages: [Stage.new(key: 'joysound', label: 'JOYSOUND', parallel: false, branches: [joysound_branch])],
          metrics: [
            metric('JOYSOUND楽曲一覧', JoysoundSong.count, '件', :admin_joysound_songs_path),
            metric('配信曲', Song.joysound.count, '曲', :admin_songs_path, filters: { karaoke_type: 'joysound' }),
            metric('家庭用対応', JoysoundSong.where(home_karaoke_enabled: true).count, '件', :admin_joysound_songs_path, filters: { service_enabled: 'home_karaoke' })
          ]
        )
      end

      def dam_workflow
        Definition.new(
          key: 'dam',
          label: 'DAM',
          description: 'DAM候補一覧を作り、必要ならアーティスト読みを補完してからカラオケ楽曲へ登録します。',
          icon: :dam_songs,
          stages: [Stage.new(key: 'dam', label: 'DAM', parallel: false, branches: [dam_branch])],
          metrics: [
            metric('DAM楽曲一覧', DamSong.count, '件', :admin_dam_songs_path),
            metric('配信曲', Song.dam.count, '曲', :admin_songs_path, filters: { karaoke_type: 'dam' }),
            metric('DAMアーティストURL', DamArtistUrl.count, '件', :admin_dam_artist_urls_path)
          ]
        )
      end

      def common_workflow
        Definition.new(
          key: 'common',
          label: '共通作業',
          description: '原曲紐付け、TSV入出力、アーティスト整理など配信種別をまたぐ作業です。',
          icon: :workflow,
          stages: [Stage.new(key: 'common', label: '共通作業', parallel: false, branches: [common_branch])],
          metrics: [
            metric('原曲未紐付け', Song.missing_original_songs.count, '曲', :admin_songs_path, filters: { original_link: 'missing' }),
            metric('読みなし', DisplayArtist.where(name_reading: [nil, '']).count, '件', :admin_display_artists_path, filters: { name_reading: 'blank' }),
            metric('孤立アーティスト', DisplayArtist.where.missing(:songs).count, '件', :admin_display_artists_path, filters: { songs: 'blank' })
          ]
        )
      end

      def music_post_branch
        Branch.new(
          key: 'music_post',
          label: 'JOYSOUND(うたスキ)',
          steps: [
            step(:joysound_music_post, :fetch_music_post, 'Music Post元データを更新する', cadence: '毎回'),
            step(:joysound_music_post, :fetch_music_post_song_joysound_url, 'Music PostとJOYSOUND楽曲URLを紐付ける', cadence: '毎回'),
            step(:display_artist, :fetch_joysound_music_post_artist, '新規アーティストがある時だけ登録・読み補完する', cadence: '新規追加時', kind: :conditional),
            step(:song, :fetch_joysound_music_post_song, '未登録または期限間近のMusic Postをカラオケ楽曲へ登録・更新する', cadence: '毎回'),
            step(:song, :refresh_joysound_music_post_song, '登録済みカラオケ楽曲のURL存在確認。削除を伴うので結果確認前提', cadence: '確認時', kind: :check),
            step(:song, :update_joysound_music_post_delivery_deadline_dates, 'Music Post側の期限をカラオケ楽曲へ反映する', cadence: '期限更新時', kind: :check),
            step(:joysound_music_post, :perform_full_joysound_music_post_maintenance, '手順4〜6と期限切れ整理をまとめて行う保守用。手順1〜3の代替ではない', cadence: '保守まとめ', kind: :maintenance, numbered: false)
          ]
        )
      end

      def joysound_branch
        Branch.new(
          key: 'joysound',
          label: 'JOYSOUND',
          steps: [
            step(:joysound_song, :fetch_joysound_touhou_songs, 'JOYSOUND東方系の候補一覧を更新する', cadence: '毎回'),
            step(:song, :fetch_joysound_songs, '候補一覧から東方対象を判定してカラオケ楽曲へ登録する', cadence: '毎回'),
            step(:display_artist, :fetch_joysound_artist, 'カラオケ楽曲登録で作られた新規アーティストの読みを補完する', cadence: '新規追加時', kind: :conditional)
          ]
        )
      end

      def dam_branch
        Branch.new(
          key: 'dam',
          label: 'DAM',
          steps: [
            step(:dam_song, :fetch_dam_touhou_songs, 'DAM候補一覧とDAMアーティストURLを作る。通常1回、件数が不自然なら再実行', cadence: '毎回'),
            step(:display_artist, :fetch_dam_artist, '新規アーティストURLがある時だけ読みを補完する', cadence: '新規追加時', kind: :conditional),
            step(:song, :fetch_dam_songs, 'DAM候補一覧の詳細をカラオケ楽曲へ登録する', cadence: '毎回'),
            step(:song, :update_dam_delivery_models, '新しいDAM配信機種が増えた時だけ再同期する', cadence: '低頻度', kind: :maintenance, numbered: false)
          ]
        )
      end

      def common_branch
        Branch.new(
          key: 'common',
          label: '共通作業',
          steps: [
            step(:song, :export_missing_original_songs, 'カラオケ楽曲登録後に原曲未設定だけを抽出する'),
            step(:song, :import_songs_with_original_songs, '編集済みTSVで原曲紐付けと配信URLを反映する', kind: :conditional),
            step(:song, :export_songs, '確認・外部反映用に現在の楽曲TSVを出力する', kind: :conditional),
            step(:display_artist, :validate_display_artist_urls, '削除前に無効URLを確認する', kind: :check),
            step(:display_artist, :cleanup_orphan_display_artists, '楽曲に紐づかないアーティストを整理する', kind: :maintenance)
          ]
        )
      end

      def step(resource_key, operation_key, note, **options)
        Step.new(
          key: "#{resource_key}:#{operation_key}",
          resource_key: resource_key.to_s,
          operation_key: operation_key.to_s,
          note:,
          cadence: options.fetch(:cadence, '必要時'),
          kind: options.fetch(:kind, :main).to_s,
          numbered: options.fetch(:numbered, true)
        )
      end

      def metric(label, value, unit, route_name, **route_options)
        { label:, value:, unit:, route_name:, route_options: }
      end
    end
  end
end
