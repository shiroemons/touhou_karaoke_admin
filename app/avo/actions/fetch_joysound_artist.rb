class FetchJoysoundArtist < Avo::BaseAction
  self.name = "Fetch joysound artist"
  self.standalone = true

  def handle(_args)
    DisplayArtist.fetch_joysound_artist
  end
end
