require 'csv'

insert_data = []
now = Time.zone.now
order = 0
CSV.table('db/fixtures/karaoke_delivery_models.tsv', col_sep: "\t", converters: nil).each do |kdm|
  order += 1
  exist = KaraokeDeliveryModel.exists?(name: kdm[:name], karaoke_type: kdm[:karaoke_type])
  next if exist

  insert_data << {
    name: kdm[:name],
    karaoke_type: kdm[:karaoke_type],
    order:,
    created_at: now,
    updated_at: now
  }
end
KaraokeDeliveryModel.insert_all(insert_data) if insert_data.present?
