module Admin
  class KaraokeSongDeliveryUrlBulkEditsController < BaseController
    PER_PAGE = 100
    SORT_OPTIONS = {
      'created_at' => 'songs.created_at',
      'display_artist_name' => 'display_artists.name',
      'title' => 'songs.title',
      'karaoke_type' => 'songs.karaoke_type',
      'youtube_url' => 'songs.youtube_url',
      'nicovideo_url' => 'songs.nicovideo_url',
      'apple_music_url' => 'songs.apple_music_url',
      'youtube_music_url' => 'songs.youtube_music_url',
      'spotify_url' => 'songs.spotify_url',
      'line_music_url' => 'songs.line_music_url'
    }.freeze
    SORT_DIRECTION_OPTIONS = %w[asc desc].freeze

    helper_method :karaoke_song_delivery_url_bulk_edit_columns,
                  :karaoke_song_delivery_url_filter_columns,
                  :karaoke_song_delivery_url_sort_options,
                  :karaoke_song_delivery_url_sort_direction_options,
                  :karaoke_song_delivery_url_karaoke_type_options

    def index
      authorize Song
      load_index
    end

    def update
      authorize Song, preview_request? ? :index? : :update?

      if preview_request?
        @preview_result = if bulk_tsv.present?
                            editor.preview_from_tsv(bulk_tsv)
                          else
                            editor.preview_from_form_rows(song_rows)
                          end
        load_index
        flash.now[:alert] = @preview_result.errors.join("\n") if @preview_result.errors.present?
        render :index, status: @preview_result.errors.present? ? :unprocessable_content : :ok
        return
      end

      result = if bulk_tsv.present?
                 editor.update_from_tsv(bulk_tsv)
               else
                 editor.update_from_form_rows(song_rows)
               end

      if result.errors.present?
        redirect_to admin_karaoke_song_delivery_url_bulk_edit_path(index_params), alert: result.errors.join("\n")
      else
        redirect_to admin_karaoke_song_delivery_url_bulk_edit_path(index_params), notice: "更新が完了しました。更新件数: #{result.updated_count}件、変更なし: #{result.skipped_count}件"
      end
    end

    private

    def load_index
      @query = params[:q].to_s.strip
      @missing_url_columns = requested_missing_url_columns
      @karaoke_type = requested_karaoke_type
      @sort = requested_sort
      @direction = requested_direction
      @page = [params[:page].to_i, 1].max
      @per_page = PER_PAGE

      scope = filtered_scope
      @total_count = scope.except(:order).count
      @total_pages = [(@total_count.to_f / @per_page).ceil, 1].max
      @songs = scope.offset((@page - 1) * @per_page).limit(@per_page)
    end

    def filtered_scope
      scope = policy_scope(Song)
              .includes(:display_artist, original_songs: :original)
              .left_outer_joins(:display_artist)

      apply_order(apply_karaoke_type_filter(apply_missing_url_filters(apply_query(scope))))
    end

    def apply_query(scope)
      return scope if @query.blank?

      pattern = "%#{Song.sanitize_sql_like(@query)}%"
      songs = Song.arel_table
      artists = DisplayArtist.arel_table
      scope.where(
        songs[:title].matches(pattern)
          .or(songs[:song_number].matches(pattern))
          .or(songs[:url].matches(pattern))
          .or(artists[:name].matches(pattern))
      )
    end

    def apply_missing_url_filters(scope)
      requested_missing_url_columns.reduce(scope) do |filtered_scope, column|
        songs = Song.arel_table
        filtered_scope.where(songs[column].eq('').or(songs[column].eq(nil)))
      end
    end

    def apply_karaoke_type_filter(scope)
      return scope if requested_karaoke_type.blank?

      scope.where(karaoke_type: requested_karaoke_type)
    end

    def apply_order(scope)
      sort_expression = SORT_OPTIONS.fetch(requested_sort)
      direction = requested_direction
      scope.reorder(Arel.sql("#{sort_expression} #{direction.upcase}"), title: :asc)
    end

    def index_params
      {
        q: params[:q].presence,
        missing_url_columns: requested_missing_url_columns.presence,
        karaoke_type: requested_karaoke_type.presence,
        sort: params[:sort].present? ? requested_sort : nil,
        direction: params[:direction].present? ? requested_direction : nil,
        page: params[:page].presence
      }.compact
    end

    def karaoke_song_delivery_url_bulk_edit_columns
      KaraokeSongDeliveryUrlBulkEditor::COLUMNS
    end

    def karaoke_song_delivery_url_filter_columns
      KaraokeSongDeliveryUrlBulkEditor::URL_COLUMNS
    end

    def karaoke_song_delivery_url_sort_options
      {
        '登録日時' => 'created_at',
        'アーティスト名' => 'display_artist_name',
        'タイトル' => 'title',
        'カラオケ種別' => 'karaoke_type',
        'youtube_url' => 'youtube_url',
        'nicovideo_url' => 'nicovideo_url',
        'apple_music_url' => 'apple_music_url',
        'youtube_music_url' => 'youtube_music_url',
        'spotify_url' => 'spotify_url',
        'line_music_url' => 'line_music_url'
      }
    end

    def karaoke_song_delivery_url_sort_direction_options
      {
        '昇順' => 'asc',
        '降順' => 'desc'
      }
    end

    def karaoke_song_delivery_url_karaoke_type_options
      Song.distinct.order(:karaoke_type).pluck(:karaoke_type).compact_blank
    end

    def requested_missing_url_columns
      Array.wrap(params[:missing_url_columns]).select do |column|
        KaraokeSongDeliveryUrlBulkEditor::URL_COLUMNS.include?(column)
      end
    end

    def requested_karaoke_type
      karaoke_type = params[:karaoke_type].to_s
      karaoke_song_delivery_url_karaoke_type_options.include?(karaoke_type) ? karaoke_type : nil
    end

    def requested_sort
      SORT_OPTIONS.key?(params[:sort].to_s) ? params[:sort].to_s : 'created_at'
    end

    def requested_direction
      SORT_DIRECTION_OPTIONS.include?(params[:direction].to_s) ? params[:direction].to_s : 'desc'
    end

    def song_rows
      rows = params[:songs]
      return {} unless rows.respond_to?(:to_unsafe_h)

      rows.to_unsafe_h
    end

    def bulk_tsv
      params[:bulk_tsv].to_s.strip
    end

    def preview_request?
      params[:mode] == 'preview'
    end

    def editor
      KaraokeSongDeliveryUrlBulkEditor.new(actor_name: current_user.name)
    end
  end
end
