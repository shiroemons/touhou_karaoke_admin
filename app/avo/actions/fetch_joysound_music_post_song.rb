class FetchJoysoundMusicPostSong < Avo::BaseAction
  self.name = "Fetch joysound music post song"
  self.standalone = true

  def handle(_args)
    Song.fetch_joysound_music_post_song
    succeed 'Done!'
    reload
  end
end
