require 'csv'

display_artists = CSV.table('tmp/display_artists_with_circles.tsv', col_sep: "\t", converters: nil, liberal_parsing: true)
display_artists.each do |display_artist|
  karaoke_type = display_artist[:karaoke_type]
  url = display_artist[:url]
  circles = display_artist[:circles]

  artist = DisplayArtist.find_by(karaoke_type:, url:)
  next unless artist && circles

  circle_list = Circle.where(name: circles.split('/'))
  artist.circles = circle_list
end
