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
end
