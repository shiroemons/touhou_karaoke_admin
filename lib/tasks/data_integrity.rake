# frozen_string_literal: true

namespace :data_integrity do
  desc 'Report duplicate rows that block future unique indexes'
  task duplicate_report: :environment do
    results = DataIntegrity::DuplicateFinder.new.call

    if results.blank?
      puts '重複データは見つかりませんでした。'
      next
    end

    results.each do |result|
      puts "[#{result.table}] #{result.columns.join(', ')}"
      result.rows.each do |row|
        values = result.columns.map { |column| "#{column}=#{row[column].inspect}" }.join(', ')
        puts "  #{values}, duplicate_count=#{row['duplicate_count']}"
      end
    end

    abort '重複データが見つかりました。削除または統合してから unique index を追加してください。'
  end

  desc 'Report impact for duplicate rows without changing data'
  task duplicate_impact_report: :environment do
    impacts = DataIntegrity::DuplicateImpactReporter.new.dam_artist_url_impacts

    if impacts.blank?
      puts 'dam_artist_urls.url の重複は見つかりませんでした。'
      next
    end

    impacts.each do |impact|
      puts "[dam_artist_urls] url=#{impact.url.inspect}, duplicate_count=#{impact.duplicate_count}"
      puts "  canonical_id=#{impact.canonical_id}"
      puts "  duplicate_ids=#{impact.duplicate_ids.join(', ')}"
      puts "  display_artist_count=#{impact.display_artist_count}"
      puts "  dam_song_count=#{impact.dam_song_count}"
      impact.rows.each do |row|
        puts "  row id=#{row.fetch(:id)}, created_at=#{row.fetch(:created_at)}, updated_at=#{row.fetch(:updated_at)}"
      end
    end
  end
end
