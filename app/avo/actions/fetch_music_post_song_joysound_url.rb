class FetchMusicPostSongJoysoundUrl < Avo::BaseAction
  self.name = I18n.t('avo.action_translations.fetch_music_post_song_joysound_url.name')
  self.standalone = true

  def handle(_args)
    JoysoundMusicPost.fetch_music_post_song_joysound_url
    succeed 'Done!'
    reload
  end
end
