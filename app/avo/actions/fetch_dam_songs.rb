class FetchDamSongs < Avo::BaseAction
  self.name = I18n.t('avo.action_translations.fetch_dam_songs.name')
  self.standalone = true

  def handle(_args)
    Song.fetch_dam_songs
    succeed 'Done!'
    reload
  end
end
