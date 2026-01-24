class FetchDamTouhouSongs < Avo::BaseAction
  self.name = I18n.t('avo.action_translations.fetch_dam_touhou_songs.name')
  self.standalone = true

  def handle(_args)
    DamSong.fetch_dam_touhou_songs
    succeed 'Done!'
    reload
  end
end
