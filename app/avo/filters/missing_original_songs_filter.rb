class MissingOriginalSongsFilter < Avo::Filters::SelectFilter
  self.name = "Missing original songs filter"

  def apply(_request, query, value)
    case value
    when 'missing_original_songs'
      query.missing_original_songs
    else
      query
    end
  end

  def options
    {
      missing_original_songs: '原曲未紐付け'
    }
  end
end
