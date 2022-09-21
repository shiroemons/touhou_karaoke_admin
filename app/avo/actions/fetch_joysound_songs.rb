class FetchJoysoundSongs < Avo::BaseAction
  self.name = "Fetch joysound songs"
  self.standalone = true

  def handle(_args)
    Song.fetch_joysound_songs
  end
end
