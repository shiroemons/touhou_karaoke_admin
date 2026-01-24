class FetchJoysoundArtist < Avo::BaseAction
  self.name = I18n.t('avo.action_translations.fetch_joysound_artist.name')
  self.standalone = true

  def handle(_args)
    DisplayArtist.fetch_joysound_artist
    succeed 'Done!'
    reload
  end
end
