class RunFetchJoysoundSongWorker
  include Sidekiq::Worker
  sidekiq_options queue: :fetch_joysound_song
  Sidekiq::Queue['fetch_joysound_song'].limit = 1

  def perform(*_args)
    JoysoundSong.fetch_joysound_song
    Song.fetch_joysound_songs
    DisplayArtist.fetch_joysound_artist
  end
end
