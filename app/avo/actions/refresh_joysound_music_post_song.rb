class RefreshJoysoundMusicPostSong < Avo::BaseAction
  self.name = "Refresh joysound music post song"
  self.standalone = true

  def handle(_args)
    Song.refresh_joysound_music_post_song
  end
end
