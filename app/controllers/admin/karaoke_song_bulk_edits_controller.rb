module Admin
  class KaraokeSongBulkEditsController < BaseController
    PER_PAGE = 100
    STATUSES = {
      'missing' => '原曲未設定',
      'linked' => '原曲設定済み',
      'all' => 'すべて'
    }.freeze

    helper_method :karaoke_song_bulk_edit_columns, :karaoke_song_bulk_edit_status_options

    def index
      authorize Song
      load_index
    end

    def update
      authorize Song, :update?

      result = if bulk_tsv.present?
                 KaraokeSongBulkEditor.new(actor_name: current_user.name).update_from_tsv(bulk_tsv)
               else
                 KaraokeSongBulkEditor.new(actor_name: current_user.name).update_from_form_rows(song_rows)
               end

      if result.errors.present?
        redirect_to admin_karaoke_song_bulk_edit_path(index_params), alert: result.errors.join("\n")
      else
        redirect_to admin_karaoke_song_bulk_edit_path(index_params), notice: "更新が完了しました。更新件数: #{result.updated_count}件、変更なし: #{result.skipped_count}件"
      end
    end

    private

    def load_index
      @status = requested_status
      @query = params[:q].to_s.strip
      @page = [params[:page].to_i, 1].max
      @per_page = PER_PAGE
      @original_song_titles = OriginalSong.non_duplicated.order(:title).pluck(:title)

      scope = filtered_scope
      @total_count = scope.except(:order).count
      @total_pages = [(@total_count.to_f / @per_page).ceil, 1].max
      @songs = scope.offset((@page - 1) * @per_page).limit(@per_page)
    end

    def filtered_scope
      scope = policy_scope(Song)
              .includes(:display_artist, original_songs: :original)
              .left_outer_joins(:display_artist)
              .order('display_artists.name asc')
              .order(title: :asc)

      scope = case requested_status
              when 'linked'
                scope.where(id: Song.with_original_songs.select(:id))
              when 'all'
                scope
              else
                scope.missing_original_songs
              end

      apply_query(scope)
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

    def requested_status
      STATUSES.key?(params[:status].to_s) ? params[:status].to_s : 'missing'
    end

    def index_params
      {
        status: requested_status,
        q: params[:q].presence,
        page: params[:page].presence
      }.compact
    end

    def karaoke_song_bulk_edit_columns
      KaraokeSongBulkEditor::COLUMNS
    end

    def karaoke_song_bulk_edit_status_options
      STATUSES
    end

    def song_rows
      rows = params[:songs]
      return {} unless rows.respond_to?(:to_unsafe_h)

      rows.to_unsafe_h
    end

    def bulk_tsv
      params[:bulk_tsv].to_s.strip
    end
  end
end
