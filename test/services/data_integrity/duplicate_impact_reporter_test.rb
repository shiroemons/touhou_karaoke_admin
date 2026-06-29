# frozen_string_literal: true

require 'test_helper'

module DataIntegrity
  class DuplicateImpactReporterTest < ActiveSupport::TestCase
    test 'reports dam artist url duplicate impact without changing rows' do
      url = 'https://example.com/dam/artists/duplicate-impact'
      records = [
        { id: SecureRandom.uuid, url:, created_at: 2.days.ago, updated_at: 2.days.ago },
        { id: SecureRandom.uuid, url:, created_at: 1.day.ago, updated_at: 1.day.ago }
      ]
      # This test intentionally creates already-corrupt data to verify the audit path.
      # rubocop:disable Rails/SkipsModelValidations
      DamArtistUrl.insert_all!(records)
      # rubocop:enable Rails/SkipsModelValidations
      artist = create_display_artist(karaoke_type: 'DAM', url:)
      DamSong.create!(display_artist: artist, title: '重複影響テスト楽曲', url: 'https://example.com/dam/songs/duplicate-impact')

      impact = DuplicateImpactReporter.new.dam_artist_url_impacts.find { |item| item.url == url }

      assert_equal 2, impact.duplicate_count
      assert_equal records.first.fetch(:id), impact.canonical_id
      assert_equal [records.second.fetch(:id)], impact.duplicate_ids
      assert_equal 1, impact.display_artist_count
      assert_equal 1, impact.dam_song_count
      assert_equal 2, DamArtistUrl.where(url:).count
    end
  end
end
