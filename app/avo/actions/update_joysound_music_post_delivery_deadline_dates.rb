class UpdateJoysoundMusicPostDeliveryDeadlineDates < Avo::BaseAction
  self.name = "JOYSOUNDミュージックポスト楽曲の配信期限を更新"
  self.standalone = true

  def handle(_args)
    Song.update_joysound_music_post_delivery_deadline_dates
    succeed 'Done!'
    reload
  end
end
