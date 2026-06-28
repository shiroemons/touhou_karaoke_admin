module Admin
  module Operations
    class HandlerRegistry
      SONG_TSV_HANDLERS = %i[export_songs export_missing_original_songs import_songs_with_original_songs].freeze
      DISPLAY_ARTIST_HANDLERS = %i[validate_display_artist_urls cleanup_invalid_display_artists cleanup_orphan_display_artists].freeze
      JOYSOUND_MUSIC_POST_HANDLERS = %i[
        fetch_joysound_music_post_song
        register_joysound_music_post_songs
        refresh_joysound_music_post_song
        verify_joysound_music_post_songs
        update_joysound_music_post_delivery_deadline_dates
        sync_joysound_music_post_delivery_deadlines
        cleanup_expired_joysound_music_posts
        perform_full_joysound_music_post_maintenance
        run_full_joysound_music_post_maintenance
      ].freeze
      KARAOKE_CANDIDATE_HANDLERS = %i[fetch_dam_song fetch_joysound_detail].freeze

      def initialize(resource:, operation:, params:, scope:)
        @resource = resource
        @operation = operation
        @params = params
        @scope = scope
      end

      def resolve(handler)
        case handler.to_sym
        when *SONG_TSV_HANDLERS
          song_tsv_operation
        when *DISPLAY_ARTIST_HANDLERS
          display_artist_operation
        when *JOYSOUND_MUSIC_POST_HANDLERS
          joysound_music_post_operation
        when *KARAOKE_CANDIDATE_HANDLERS
          karaoke_candidate_operation
        end
      end

      private

      attr_reader :operation, :params, :scope

      def song_tsv_operation
        @song_tsv_operation ||= SongTsvOperation.new(resource: @resource, operation:, params:, scope:)
      end

      def display_artist_operation
        @display_artist_operation ||= DisplayArtistOperation.new(params:)
      end

      def joysound_music_post_operation
        @joysound_music_post_operation ||= JoysoundMusicPostOperation.new(params:)
      end

      def karaoke_candidate_operation
        @karaoke_candidate_operation ||= KaraokeCandidateOperation.new(params:)
      end
    end
  end
end
