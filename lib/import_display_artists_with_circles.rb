require 'csv'

display_artists = CSV.table('tmp/display_artists_with_circles.tsv', col_sep: "\t", converters: nil, liberal_parsing: true)

artist_total = DisplayArtist.count
total_count = display_artists.size

display_artists.each.with_index(1) do |display_artist, i|
  print "\rArtistTotal:#{artist_total}\t#{i}/#{total_count}: Progress: #{(i * 100.0 / total_count).round(1)}%"

  karaoke_type = display_artist[:karaoke_type]
  url = display_artist[:url]
  circles = display_artist[:circles]

  artist = DisplayArtist.find_by(karaoke_type:, url:)
  next unless artist && circles

  circle_list = Circle.where(name: circles.split('/'))
  artist.circles = circle_list
end
