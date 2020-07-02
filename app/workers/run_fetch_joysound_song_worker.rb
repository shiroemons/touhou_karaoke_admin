class RunFetchJoysoundSongWorker
  include Sidekiq::Worker
  sidekiq_options queue: :fetch_joysound_song
  Sidekiq::Queue['fetch_joysound_song'].limit = 1

  def perform(*args)
    JoysoundSong.fetch_joysound_song
  end
end
