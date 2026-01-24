class FetchDamArtist < Avo::BaseAction
  self.name = I18n.t('avo.action_translations.fetch_dam_artist.name')
  self.standalone = true

  def handle(_args)
    DamArtistUrl.fetch_dam_artist
    succeed 'Done!'
    reload
  end
end
