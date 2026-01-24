class UpdateDamDeliveryModels < Avo::BaseAction
  self.name = I18n.t('avo.action_translations.update_dam_delivery_models.name')
  self.standalone = true

  def handle(_args)
    Song.update_dam_delivery_models
    succeed 'Done!'
    reload
  end
end
