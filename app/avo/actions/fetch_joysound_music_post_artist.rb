class FetchJoysoundMusicPostArtist < Avo::BaseAction
  self.name = I18n.t('avo.action_translations.fetch_joysound_music_post_artist.name')
  self.standalone = true

  def handle(_args)
    DisplayArtist.fetch_joysound_music_post_artist
    succeed 'Done!'
    reload
  end
end
