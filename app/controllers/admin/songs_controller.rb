module Admin
  class SongsController < ResourcesController
    self.resource_key = :song

    # NOTE: intentionally a distinct callback name (not `:set_record`). Redeclaring
    # `before_action :set_record, only: ...` here would replace ResourcesController's
    # existing `set_record` callback (Rails callback chains key on the method symbol),
    # silently dropping `show`/`edit`/`update`/etc. from its `only:` list.
    before_action :set_record_for_original_songs, only: :original_songs

    def original_songs
      authorize @record, :update?

      result = KaraokeSongBulkEditor.new(actor_name: current_user.name).update_original_songs_for(@record, params[:original_songs])

      if result.errors.present?
        redirect_to admin_resource_path(@resource, @record), alert: result.errors.join("\n")
      else
        DashboardCache.invalidate! if result.updated_count.positive?
        notice = result.updated_count.positive? ? '原曲紐づけを更新しました。' : '変更はありませんでした。'
        redirect_to admin_resource_path(@resource, @record), notice:
      end
    end

    private

    def set_record_for_original_songs
      set_record
    end
  end
end
