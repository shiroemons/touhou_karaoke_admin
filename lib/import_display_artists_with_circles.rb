require 'csv'

display_artists = CSV.table('tmp/display_artists_with_circles.tsv', col_sep: "\t", converters: nil, liberal_parsing: true)

artist_total = DisplayArtist.count
total_count = display_artists.size

karaoke_types = display_artists.pluck(:karaoke_type).uniq
urls = display_artists.pluck(:url).uniq
artists_by_key = DisplayArtist.where(karaoke_type: karaoke_types, url: urls)
                              .index_by { |artist| [artist.karaoke_type, artist.url] }

circle_names_pool = display_artists.flat_map { |row| row[:circles].to_s.split('/') }.uniq
circles_by_name = Circle.where(name: circle_names_pool).group_by(&:name)

display_artists.each.with_index(1) do |display_artist, i|
  print "\rArtistTotal:#{artist_total}\t#{i}/#{total_count}: Progress: #{(i * 100.0 / total_count).round(1)}%"

  karaoke_type = display_artist[:karaoke_type]
  url = display_artist[:url]
  circles = display_artist[:circles]

  artist = artists_by_key[[karaoke_type, url]]
  next unless artist && circles

  circle_list = circles.split('/').flat_map { |name| circles_by_name[name] || [] }.uniq
  artist.circles = circle_list
end
