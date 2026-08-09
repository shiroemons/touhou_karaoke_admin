# frozen_string_literal: true

module DataIntegrity
  # 同じ配信種別・曲URL・タイトルを持つSongを、情報量の多いレコードへ統合する。
  # 外部URLの確認が必要なアーティストURL変更は、更新前に必ずdry-run判定を行う。
  class SongDuplicateReconciler
    KARAOKE_TYPE = 'JOYSOUND(うたスキ)'

    COPYABLE_ATTRIBUTES = %w[
      song_number
      title_reading
      youtube_url
      nicovideo_url
      apple_music_url
      youtube_music_url
      spotify_url
      line_music_url
    ].freeze

    def initialize(
      scope: Song.where(karaoke_type: KARAOKE_TYPE),
      dry_run: true,
      progress: nil,
      artist_resolver: JoysoundDisplayArtistResolver.new
    )
      @scope = scope
      @dry_run = dry_run
      @progress = progress
      @artist_resolver = artist_resolver
    end

    def call
      groups = duplicate_keys
      reporter = progress_reporter
      reporter&.start(total: groups.size)

      results = groups.each_with_index.map do |key, index|
        result = reconcile_group(key)
        reporter&.advance(current: index + 1, total: groups.size, force: true)
        result
      end

      {
        checked: results.size,
        reconciled: results.count { |result| result[:status].in?(%i[reconciled would_reconcile]) },
        skipped: results.count { |result| result[:status] == :skipped },
        songs_deleted: results.sum { |result| result[:songs_deleted] },
        songs_to_delete: results.sum { |result| result[:songs_to_delete] },
        artists_updated: results.sum { |result| result[:artists_updated] },
        artists_to_update: results.sum { |result| result[:artists_to_update] },
        orphan_artists_deleted: results.sum { |result| result[:orphan_artists_deleted] },
        orphan_artists_to_delete: results.sum { |result| result[:orphan_artists_to_delete] },
        groups: results,
        errors: results.filter_map { |result| result[:error] }
      }
    end

    private

    attr_reader :scope, :progress, :artist_resolver

    def duplicate_keys
      scope
        .group(:karaoke_type, :url, :title)
        .having('COUNT(*) > 1')
        .order(:karaoke_type, :url, :title)
        .pluck(:karaoke_type, :url, :title)
    end

    def reconcile_group(key)
      karaoke_type, url, title = key
      songs = Song
              .where(karaoke_type:, url:, title:)
              .includes(
                :display_artist,
                :song_with_dam_ouchikaraoke,
                :song_with_joysound_utasuki,
                :songs_karaoke_delivery_models,
                :songs_original_songs
              )
              .order(:created_at, :id)
              .to_a
      canonical = select_canonical_song(songs)
      duplicates = songs - [canonical]

      preflight = preflight_group(canonical, duplicates)
      return skipped_result(key:, canonical:, duplicates:, reason: preflight[:reason]) unless preflight[:safe]

      if dry_run?
        return planned_result(
          key:,
          canonical:,
          duplicates:,
          artist_resolutions: preflight[:artist_resolutions]
        )
      end

      deleted_artist_ids = []
      ActiveRecord::Base.transaction do
        duplicates.each do |duplicate|
          merge_song!(canonical, duplicate)
          duplicate_artist = duplicate.display_artist
          duplicate.destroy!
          next unless orphan_artist?(duplicate_artist)

          duplicate_artist.destroy!
          deleted_artist_ids << duplicate_artist.id
        end
        apply_artist_resolutions(preflight[:artist_resolutions])
      end

      reconciled_result(
        key:,
        canonical:,
        duplicates:,
        artist_resolutions: preflight[:artist_resolutions],
        orphan_artist_ids: deleted_artist_ids
      )
    rescue StandardError => e
      Admin::OperationLogger.log(
        level: :error,
        event: :db_update,
        action: :error,
        resource: :song,
        karaoke_type:,
        url:,
        title:,
        error: e.message
      )
      skipped_result(key:, canonical:, duplicates:, reason: e.message, error: e.message)
    end

    def preflight_group(canonical, duplicates)
      return { safe: false, reason: '重複曲の関連データを安全に統合できません' } unless duplicates.all? { |duplicate| mergeable?(canonical, duplicate) }

      artist_resolutions = duplicates.map do |duplicate|
        resolve_duplicate_artist(canonical, duplicate)
      end
      return { safe: false, reason: 'アーティスト情報を自動判定できません' } if artist_resolutions.any? { |resolution| resolution[:status] == :unsafe }

      update_urls = artist_resolutions.filter_map { |resolution| resolution[:new_url] }.uniq
      return { safe: false, reason: '更新候補のアーティストURLが複数あります' } if update_urls.size > 1

      { safe: true, artist_resolutions: }
    end

    def resolve_duplicate_artist(canonical, duplicate)
      canonical_artist = canonical.display_artist
      duplicate_artist = duplicate.display_artist

      return { status: :unsafe, reason: 'アーティスト名または種別が一致しません' } unless canonical_artist.name == duplicate_artist.name && canonical_artist.karaoke_type == duplicate_artist.karaoke_type
      return { status: :unsafe, reason: '重複側アーティストに他の関連データがあります' } if canonical_artist.id != duplicate_artist.id && duplicate_artist_has_other_references?(duplicate_artist, duplicate.id)

      return { status: :safe, action: :unchanged, artist: canonical_artist, new_url: nil } if canonical_artist.url == duplicate_artist.url

      resolution = artist_resolver.resolve(
        name: duplicate_artist.name,
        karaoke_type: canonical.karaoke_type,
        url: duplicate_artist.url,
        existing_song: canonical,
        dry_run: true
      )

      return { status: :safe, action: resolution.action, artist: canonical_artist, new_url: resolution.new_url, resolution: } if resolution.action == :would_update_url

      { status: :unsafe, reason: resolution.reason, resolution: }
    end

    def mergeable?(canonical, duplicate)
      COPYABLE_ATTRIBUTES.all? do |attribute|
        canonical_value = canonical.public_send(attribute).to_s
        duplicate_value = duplicate.public_send(attribute).to_s
        canonical_value.blank? || duplicate_value.blank? || canonical_value == duplicate_value
      end && mergeable_details?(canonical, duplicate)
    end

    def mergeable_details?(canonical, duplicate)
      mergeable_detail?(canonical.song_with_dam_ouchikaraoke, duplicate.song_with_dam_ouchikaraoke) &&
        mergeable_detail?(canonical.song_with_joysound_utasuki, duplicate.song_with_joysound_utasuki)
    end

    def mergeable_detail?(canonical_detail, duplicate_detail)
      return true if canonical_detail.nil? || duplicate_detail.nil?

      canonical_detail.attributes.except('id', 'song_id', 'created_at', 'updated_at') ==
        duplicate_detail.attributes.except('id', 'song_id', 'created_at', 'updated_at')
    end

    def select_canonical_song(songs)
      songs.min_by do |song|
        [-song_data_score(song), song.created_at, song.id]
      end
    end

    def song_data_score(song)
      score = 0
      score += 100 if song.song_with_joysound_utasuki.present?
      score += 100 if song.song_with_dam_ouchikaraoke.present?
      score += song.songs_original_songs.size * 20
      score += song.songs_karaoke_delivery_models.size * 10
      score + COPYABLE_ATTRIBUTES.count { |attribute| song.public_send(attribute).present? }
    end

    def apply_artist_resolutions(resolutions)
      resolutions.each do |resolution|
        next unless resolution[:action] == :would_update_url

        artist = resolution[:artist].class.lock.find(resolution[:artist].id)
        artist.update!(url: resolution.fetch(:new_url))
        Admin::OperationLogger.log(
          level: :info,
          event: :db_update,
          action: :update_url,
          resource: :display_artist,
          id: artist.id,
          name: artist.name,
          old_url: artist.url_before_last_save,
          new_url: artist.url
        )
      end
    end

    def merge_song!(canonical, duplicate)
      copy_song_attributes!(canonical, duplicate)
      merge_delivery_models!(canonical, duplicate)
      merge_original_songs!(canonical, duplicate)
      merge_detail!(canonical, duplicate, :song_with_dam_ouchikaraoke)
      merge_detail!(canonical, duplicate, :song_with_joysound_utasuki)
      canonical.save! if canonical.changed?
    end

    def copy_song_attributes!(canonical, duplicate)
      COPYABLE_ATTRIBUTES.each do |attribute|
        next if canonical.public_send(attribute).present?

        value = duplicate.public_send(attribute)
        canonical.public_send("#{attribute}=", value) if value.present?
      end
    end

    def merge_delivery_models!(canonical, duplicate)
      canonical.songs_karaoke_delivery_models
               .joins(:karaoke_delivery_model)
               .where.not(karaoke_delivery_models: { karaoke_type: canonical.karaoke_type })
               .destroy_all

      duplicate.songs_karaoke_delivery_models.each do |link|
        next unless link.karaoke_delivery_model.karaoke_type == canonical.karaoke_type

        SongsKaraokeDeliveryModel.find_or_create_association(canonical.id, link.karaoke_delivery_model_id)
      end
    end

    def merge_original_songs!(canonical, duplicate)
      duplicate.songs_original_songs.each do |link|
        next if canonical.songs_original_songs.exists?(original_song_code: link.original_song_code)

        SongsOriginalSong.create!(song: canonical, original_song_code: link.original_song_code)
      end
    end

    def merge_detail!(canonical, duplicate, association_name)
      canonical_detail = canonical.public_send(association_name)
      duplicate_detail = duplicate.public_send(association_name)
      return if duplicate_detail.nil?
      return if canonical_detail.present?

      duplicate_detail.update!(song: canonical)
    end

    def orphan_artist?(artist)
      artist.reload
      artist.songs.none? && artist.dam_songs.none? && artist.circles.none?
    end

    def planned_result(key:, canonical:, duplicates:, artist_resolutions:)
      karaoke_type, url, title = key

      {
        status: :would_reconcile,
        karaoke_type:,
        url:,
        title:,
        canonical_id: canonical.id,
        duplicate_ids: duplicates.map(&:id),
        songs_deleted: 0,
        songs_to_delete: duplicates.size,
        artists_updated: 0,
        artists_to_update: artist_resolutions.count { |resolution| resolution[:action] == :would_update_url },
        orphan_artists_deleted: 0,
        orphan_artists_to_delete: duplicates.count { |duplicate| orphan_artist_candidate?(duplicate.display_artist, excluding_song_id: duplicate.id) },
        artist_url_updates: artist_resolutions.filter_map { |resolution| resolution_summary(resolution[:resolution]) },
        reason: :safe_to_reconcile
      }
    end

    def reconciled_result(key:, canonical:, duplicates:, artist_resolutions:, orphan_artist_ids:)
      karaoke_type, url, title = key

      {
        status: :reconciled,
        karaoke_type:,
        url:,
        title:,
        canonical_id: canonical.id,
        duplicate_ids: duplicates.map(&:id),
        songs_deleted: duplicates.size,
        songs_to_delete: duplicates.size,
        artists_updated: artist_resolutions.count { |resolution| resolution[:action] == :would_update_url },
        artists_to_update: artist_resolutions.count { |resolution| resolution[:action] == :would_update_url },
        orphan_artists_deleted: orphan_artist_ids.size,
        orphan_artists_to_delete: orphan_artist_ids.size,
        artist_url_updates: artist_resolutions.filter_map { |resolution| resolution_summary(resolution[:resolution]) },
        orphan_artist_ids: orphan_artist_ids,
        reason: :reconciled
      }
    end

    def skipped_result(key:, canonical:, duplicates:, reason:, error: nil)
      karaoke_type, url, title = key

      {
        status: :skipped,
        karaoke_type:,
        url:,
        title:,
        canonical_id: canonical&.id,
        duplicate_ids: duplicates&.map(&:id) || [],
        songs_deleted: 0,
        songs_to_delete: 0,
        artists_updated: 0,
        artists_to_update: 0,
        orphan_artists_deleted: 0,
        orphan_artists_to_delete: 0,
        artist_url_updates: [],
        reason:,
        error:
      }
    end

    def orphan_artist_candidate?(artist, excluding_song_id:)
      artist.songs.where.not(id: excluding_song_id).none? && artist.dam_songs.none? && artist.circles.none?
    end

    def duplicate_artist_has_other_references?(artist, excluding_song_id)
      !orphan_artist_candidate?(artist, excluding_song_id:)
    end

    def resolution_summary(resolution)
      return unless resolution

      {
        action: resolution.action,
        reason: resolution.reason,
        old_url: resolution.old_url,
        new_url: resolution.new_url,
        old_status_code: resolution.old_check&.[](:status_code),
        new_status_code: resolution.new_check&.[](:status_code)
      }
    end

    def dry_run?
      @dry_run
    end

    def progress_reporter
      return unless progress

      Admin::ProgressReporter.new(
        progress:,
        status: dry_run? ? '重複曲確認中' : '重複曲整理中',
        label: dry_run? ? '重複登録された曲を確認しています' : '重複登録された曲を整理しています'
      )
    end
  end
end
