module Admin
  class KaraokeSongDeliveryUrlBulkEditsController < BaseController
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
      query = index_query
      @query = query.query
      @missing_url_columns = query.missing_url_columns
      @karaoke_type = query.karaoke_type
      @sort = query.sort
      @direction = query.direction
      @page = query.page
      @per_page = query.per_page
      @total_count = query.total_count
      @total_pages = query.total_pages
      @songs = query.songs
    end

    def index_params
      index_query.index_params
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
      @karaoke_song_delivery_url_karaoke_type_options ||= Song.distinct.order(:karaoke_type).pluck(:karaoke_type).compact_blank
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

    def index_query
      @index_query ||= KaraokeSongDeliveryUrlBulkEditQuery.new(
        scope: policy_scope(Song),
        params:,
        karaoke_type_options: karaoke_song_delivery_url_karaoke_type_options
      )
    end
  end
end
