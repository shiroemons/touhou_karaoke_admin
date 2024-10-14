class FetchJoysoundArtist < Avo::BaseAction
  self.name = "JOYSOUNDのアーティストを取得"
  self.standalone = true

  def handle(_args)
    DisplayArtist.fetch_joysound_artist
    succeed 'Done!'
    reload
  end
end
