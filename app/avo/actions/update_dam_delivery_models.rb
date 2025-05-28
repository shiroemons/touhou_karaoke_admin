class UpdateDamDeliveryModels < Avo::BaseAction
  self.name = "DAM楽曲の機種情報を更新"
  self.standalone = true

  def handle(_args)
    Song.update_dam_delivery_models
    succeed 'Done!'
    reload
  end
end
