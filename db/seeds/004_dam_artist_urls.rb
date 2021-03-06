require 'csv'

insert_data = []
now = Time.now
CSV.table('db/fixtures/dam_artist_url.tsv', col_sep: "\t", converters: nil).each do |dau|
  exist = DamArtistUrl.exists?(url: dau[:url])
  unless exist
    insert_data << {
      url: dau[:url],
      created_at: now,
      updated_at: now
    }
  end
end
DamArtistUrl.insert_all!(insert_data) if insert_data.present?