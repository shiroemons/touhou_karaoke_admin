class JoysoundMusicPostCount < Avo::Dashboards::MetricCard
  self.id = "joysound_music_post_count"
  self.label = "JOYSOUND MUSIC POST count"
  self.suffix = '曲'

  def query
    result JoysoundMusicPost.count
  end
end
