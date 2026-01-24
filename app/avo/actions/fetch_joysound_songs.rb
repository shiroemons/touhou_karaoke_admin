class FetchJoysoundSongs < Avo::BaseAction
  self.name = I18n.t('avo.action_translations.fetch_joysound_songs.name')
  self.standalone = true

  def handle(_args)
    Song.fetch_joysound_songs
    succeed 'Done!'
    reload
  end
end
