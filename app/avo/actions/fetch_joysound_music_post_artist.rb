class FetchJoysoundMusicPostArtist < Avo::BaseAction
  self.name = "Fetch joysound music post artist"
  self.standalone = true

  def handle(_args)
    DisplayArtist.fetch_joysound_music_post_artist
    succeed 'Done!'
    reload
  end
end
