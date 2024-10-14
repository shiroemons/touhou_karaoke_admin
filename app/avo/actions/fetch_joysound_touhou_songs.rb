class FetchJoysoundTouhouSongs < Avo::BaseAction
  self.name = "JOYSOUNDの東方楽曲を取得"
  self.standalone = true

  def handle(_args)
    JoysoundSong.fetch_joysound_touhou_songs
    succeed 'Done!'
    reload
  end
end
