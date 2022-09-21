class KaraokeTypeFilter < Avo::Filters::SelectFilter
  self.name = "Karaoke type filter"

  def apply(_request, query, value)
    case value
    when 'dam'
      query.dam
    when 'joysound'
      query.joysound
    when 'joysound_music_post'
      query.music_post
    else
      query
    end
  end

  def options
    {
      dam: "DAM",
      joysound: "JOYSOUND",
      joysound_music_post: "JOYSOUND(うたスキ)"
    }
  end
end
