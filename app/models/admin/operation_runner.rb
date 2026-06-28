module Admin
  class OperationRunner
    class InputError < StandardError; end

    Result = Data.define(:message, :download_data, :download_filename, :download_content_type)

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

    def initialize(resource:, operation:, record:, params:, scope:)
      @resource = resource
      @operation = operation
      @record = record
      @params = params
      @scope = scope
      @progress_id = params[:operation_progress_id]
    end

    def run
      started_at = Time.current
      change_summary = OperationChangeSummary.new
      change_baseline = change_summary.snapshot
      OperationProgress.start!(progress_id, label: operation.label)
      result = operation.handler.blank? ? run_method_operation : run_handler_operation

      OperationProgress.complete!(
        progress_id,
        label: result.message.presence || '処理が完了しました',
        detail: change_summary.summarize(baseline: change_baseline, started_at:)
      )
      result
    rescue StandardError => e
      OperationProgress.fail!(progress_id, message: e.message)
      raise
    end

    private

    attr_reader :operation, :record, :params, :scope, :progress_id

    def song_tsv_operation
      @song_tsv_operation ||= Operations::SongTsvOperation.new(resource: @resource, operation:, params:, scope:)
    end

    def display_artist_operation
      @display_artist_operation ||= Operations::DisplayArtistOperation.new(params:)
    end

    def joysound_music_post_operation
      @joysound_music_post_operation ||= Operations::JoysoundMusicPostOperation.new(params:)
    end

    def karaoke_candidate_operation
      @karaoke_candidate_operation ||= Operations::KaraokeCandidateOperation.new(params:)
    end

    def run_method_operation
      target = record || operation_target
      operation_method = target.method(operation.method_name)
      if operation_method.parameters.any? { |type, name| type == :key && name == :progress }
        target.public_send(operation.method_name, progress: method_progress)
      else
        target.public_send(operation.method_name)
      end
      message("#{operation.label}を実行しました。")
    end

    def run_handler_operation
      target = handler_operation_target
      handler_method = target.method(operation.handler)
      if handler_method.parameters.any? { |type, name| type == :key && name == :progress }
        target.public_send(operation.handler, progress: method_progress)
      else
        target.public_send(operation.handler)
      end
    end

    def handler_operation_target
      case operation.handler.to_sym
      when *SONG_TSV_HANDLERS
        song_tsv_operation
      when *DISPLAY_ARTIST_HANDLERS
        display_artist_operation
      when *JOYSOUND_MUSIC_POST_HANDLERS
        joysound_music_post_operation
      when *KARAOKE_CANDIDATE_HANDLERS
        karaoke_candidate_operation
      else
        self
      end
    end

    def method_progress
      lambda do |**attributes|
        OperationProgress.update!(progress_id, **attributes)
      end
    end

    def operation_target
      @resource.model
    end

    def message(text)
      Result.new(message: text, download_data: nil, download_filename: nil, download_content_type: nil)
    end
  end
end
