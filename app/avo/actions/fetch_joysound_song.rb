class FetchJoysoundSong < Avo::BaseAction
  self.name = "Fetch joysound song"
  self.standalone = true

  def handle(_args)
    JoysoundSong.fetch_joysound_song
  end
end
