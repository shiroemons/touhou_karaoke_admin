module Admin
  class OperationRunner
    class InputError < StandardError; end

    Result = Data.define(:message, :download_data, :download_filename, :download_content_type)

    UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

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

    def fetch_dam_song(progress: nil)
      url = params.dig(:operation_fields, :dam_song_url).to_s
      raise InputError, 'DAMの楽曲URLではありません。' unless url.start_with?(Constants::Karaoke::Dam::SONG_URL)

      progress&.call(percentage: 25, status: 'DAM候補追加中', label: '指定URLからDAM候補を取得しています', detail: nil)
      DamSong.fetch_dam_song(url)
      progress&.call(percentage: 96, status: 'DAM候補追加中', label: 'DAM候補の保存が完了しました', detail: nil)
      message('DAM候補を追加しました。')
    end

    def fetch_joysound_detail(progress: nil)
      url = params.dig(:operation_fields, :joysound_url).to_s
      raise InputError, 'JOYSOUNDの楽曲URLではありません。' unless url.start_with?("#{Constants::Karaoke::Joysound::SEARCH_URL}/")

      progress&.call(percentage: 25, status: 'JOYSOUND候補追加中', label: '指定URLからJOYSOUND候補を取得しています', detail: nil)
      JoysoundSong.fetch_joysound_song_direct(url:)
      progress&.call(percentage: 96, status: 'JOYSOUND候補追加中', label: 'JOYSOUND候補の保存が完了しました', detail: nil)
      message('JOYSOUND候補を追加しました。')
    end

    private

    attr_reader :operation, :record, :params, :scope, :progress_id

    def song_tsv_operation
      @song_tsv_operation ||= Operations::SongTsvOperation.new(params:, scope: operation_scope)
    end

    def display_artist_operation
      @display_artist_operation ||= Operations::DisplayArtistOperation.new(params:)
    end

    def joysound_music_post_operation
      @joysound_music_post_operation ||= Operations::JoysoundMusicPostOperation.new(params:)
    end

    def operation_scope
      ids = selected_ids
      raise InputError, '対象を選択してください。' if operation.selection == :required && ids.blank?
      return scope if ids.blank? && !selected_ids_submitted?
      return scope.none if ids.blank?

      scope.where(@resource.model.primary_key => ids)
    end

    def selected_ids_submitted?
      params.key?(:selected_ids) || params.key?('selected_ids')
    end

    def selected_ids
      raw_ids = Array(params[:selected_ids]).map(&:to_s).compact_blank.uniq
      return [] if raw_ids.blank?
      return raw_ids unless uuid_primary_key?

      raw_ids.grep(UUID_PATTERN)
    end

    def uuid_primary_key?
      @resource.model.columns_hash.fetch(@resource.model.primary_key).type == :uuid
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
      [song_tsv_operation, display_artist_operation, joysound_music_post_operation].find do |target|
        target.respond_to?(operation.handler)
      end || self
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

    def download(data, filename)
      Result.new(
        message: "#{filename}を生成しました。",
        download_data: data,
        download_filename: filename,
        download_content_type: 'text/tab-separated-values; charset=utf-8'
      )
    end
  end
end
