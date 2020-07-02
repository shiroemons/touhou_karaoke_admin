class RunFetchJoysoundMusicPostWorker
  include Sidekiq::Worker
  sidekiq_options queue: :fetch_joysound_music_post
  Sidekiq::Queue['fetch_joysound_music_post'].limit = 1

  def perform(*args)
    JoysoundMusicPost.fetch_music_post
  end
end
