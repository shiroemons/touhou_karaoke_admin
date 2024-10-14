class FetchMusicPost < Avo::BaseAction
  self.name = "JOYSOUNDミュージックポストの東方楽曲を取得"
  self.standalone = true

  def handle(_args)
    JoysoundMusicPost.fetch_music_post
    succeed 'Done!'
    reload
  end
end
