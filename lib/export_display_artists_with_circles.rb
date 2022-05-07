File.open('tmp/display_artists_with_circles.tsv', 'w') do |f|
  f.puts "karaoke_type\tname\tname_reading\turl\tcircles"
  DisplayArtist.includes(:circles).order(:karaoke_type).each do |artist|
    next if artist.url == 'https://www.joysound.com/web/search/artist/'

    karaoke_type = artist.karaoke_type
    name = artist.name
    name_reading = artist.name_reading
    url = artist.url
    circles = artist.circles.map(&:name).join('/')

    f.puts "#{karaoke_type}\t#{name}\t#{name_reading}\t#{url}\t#{circles}"
  end
end
