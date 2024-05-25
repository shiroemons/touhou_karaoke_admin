class FetchJoysoundTouhouSongs < Avo::BaseAction
  self.name = "Fetch joysound touhou songs"
  self.standalone = true

  def handle(_args)
    JoysoundSong.fetch_joysound_touhou_songs
    succeed 'Done!'
    reload
  end
end
