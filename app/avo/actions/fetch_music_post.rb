class FetchMusicPost < Avo::BaseAction
  self.name = I18n.t('avo.action_translations.fetch_music_post.name')
  self.standalone = true

  def handle(_args)
    JoysoundMusicPost.fetch_music_post
    succeed 'Done!'
    reload
  end
end
