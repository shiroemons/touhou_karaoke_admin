class FetchMusicPost < Avo::BaseAction
  self.name = "Fetch music post"
  self.standalone = true

  def handle(_args)
    JoysoundMusicPost.fetch_music_post
  end
end
