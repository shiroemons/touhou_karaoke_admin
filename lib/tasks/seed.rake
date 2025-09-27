namespace :db do
  namespace :seed do
    desc "Update only originals and original_songs data"
    task update_originals: :environment do
      puts "Starting update of originals and original_songs..."
      load Rails.root.join('db/seeds/update_originals_only.rb')
      puts "Update completed!"
    end

    desc "Import originals data only"
    task originals: :environment do
      puts "Importing originals..."
      require 'csv'

      ActiveRecord::Base.connection.execute("TRUNCATE TABLE originals RESTART IDENTITY CASCADE;")
      now = Time.zone.now
      insert_data = CSV.table('db/fixtures/originals.tsv', col_sep: "\t", converters: nil).map do |o|
        {
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
      puts "Originals imported: #{insert_data.length} records"
    end

    desc "Import original_songs data only"
    task original_songs: :environment do
      puts "Importing original songs..."
      require 'csv'

      ActiveRecord::Base.connection.execute("TRUNCATE TABLE original_songs RESTART IDENTITY CASCADE;")
      now = Time.zone.now
      insert_data = CSV.table('db/fixtures/original_songs.tsv', col_sep: "\t", converters: nil).map do |os|
        {
          code: os[:code],
          original_code: os[:original_code],
          title: os[:title],
          composer: os[:composer].to_s,
          track_number: os[:track_number].to_i,
          is_duplicate: os[:is_duplicate].to_s == '1',
          created_at: now,
          updated_at: now
        }
      end
      OriginalSong.insert_all(insert_data)
      puts "Original songs imported: #{insert_data.length} records"
    end

    desc "Import both originals and original_songs data (truncate and reimport)"
    task originals_all: :environment do
      Rake::Task['db:seed:originals'].invoke
      Rake::Task['db:seed:original_songs'].invoke
    end
  end
end
