class FetchJoysoundTouhouSongs < Avo::BaseAction
  self.name = I18n.t('avo.action_translations.fetch_joysound_touhou_songs.name')
  self.standalone = true

  def handle(_args)
    JoysoundSong.fetch_joysound_touhou_songs
    succeed 'Done!'
    reload
  end
end
