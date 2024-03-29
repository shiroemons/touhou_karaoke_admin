require 'csv'

ActiveRecord::Base.connection.execute("TRUNCATE TABLE originals;")
insert_data = []
now = Time.zone.now
CSV.table('db/fixtures/originals.tsv', col_sep: "\t", converters: nil).each do |o|
  insert_data << {
    code: o[:code],
    title: o[:title],
    short_title: o[:short_title],
    original_type: o[:original_type],
    series_order: o[:series_order],
    created_at: now,
    updated_at: now
  }
end
Original.insert_all(insert_data)
