class SongsCount < Avo::Dashboards::MetricCard
  self.id = "songs_count"
  self.label = "Songs count"
  self.suffix = '曲'

  def query
    scope = Song

    scope = scope.dam if options[:dam].present?
    scope = scope.joysound if options[:joysound].present?
    scope = scope.music_post if options[:music_post].present?
    scope = scope.touhou_arrange if options[:touhou].present?
    scope = scope.missing_original_songs if options[:missing_original_songs].present?

    result scope.count
  end
end
