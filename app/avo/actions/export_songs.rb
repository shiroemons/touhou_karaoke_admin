# frozen_string_literal: true

class ExportSongs < Avo::BaseAction
  self.name = 'Export songs'
  self.visible = -> { view == :index }
  self.may_download_file = true

  def handle(args)
    models = args.values_at(:models).first

    tsv_data = CSV.generate(col_sep: "\t") do |csv|
      csv << %w[id karaoke_type display_artist_name title original_songs youtube_url nicovideo_url apple_music_url youtube_music_url spotify_url line_music_url]
      models.each do |song|
        column_values = [
          song.id,
          song.karaoke_type,
          song.display_artist.name,
          song.title,
          song.original_songs.map(&:title).join('/'),
          song.youtube_url,
          song.nicovideo_url,
          song.apple_music_url,
          song.youtube_music_url,
          song.spotify_url,
          song.line_music_url
        ]
        csv << column_values
      end
    end

    download tsv_data, 'songs.tsv'
  end
end
