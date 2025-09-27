require 'csv'

puts "Updating originals..."
csv_data = CSV.table('db/fixtures/originals.tsv', col_sep: "\t", converters: nil)
csv_data.each do |row|
  original = Original.find_or_initialize_by(code: row[:code])
  original.assign_attributes(
    title: row[:title],
    short_title: row[:short_title],
    original_type: row[:original_type],
    series_order: row[:series_order]
  )
  if original.new_record?
    puts "  Creating new original: #{row[:code]}"
  elsif original.changed?
    puts "  Updating original: #{row[:code]}"
  end
  original.save!
end
puts "Originals updated: #{csv_data.length} records processed"

puts "\nUpdating original songs..."
csv_data = CSV.table('db/fixtures/original_songs.tsv', col_sep: "\t", converters: nil)
csv_data.each do |row|
  original_song = OriginalSong.find_or_initialize_by(code: row[:code])
  original_song.assign_attributes(
    original_code: row[:original_code],
    title: row[:title],
    composer: row[:composer].to_s,
    track_number: row[:track_number].to_i,
    is_duplicate: row[:is_duplicate].to_s == '1'
  )
  if original_song.new_record?
    puts "  Creating new original song: #{row[:code]}"
  elsif original_song.changed?
    puts "  Updating original song: #{row[:code]}"
  end
  original_song.save!
end
puts "Original songs updated: #{csv_data.length} records processed"
