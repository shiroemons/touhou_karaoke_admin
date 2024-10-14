class FetchJoysoundSongs < Avo::BaseAction
  self.name = "JOYSOUNDの楽曲を取得"
  self.standalone = true

  def handle(_args)
    Song.fetch_joysound_songs
    succeed 'Done!'
    reload
  end
end
