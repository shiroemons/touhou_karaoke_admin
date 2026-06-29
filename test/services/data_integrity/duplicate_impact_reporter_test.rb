# frozen_string_literal: true

require 'test_helper'

module DataIntegrity
  class DuplicateImpactReporterTest < ActiveSupport::TestCase
    test 'omits dam artist url impact when urls are unique' do
      url = 'https://example.com/dam/artists/duplicate-impact'
      DamArtistUrl.create!(url:)
      artist = create_display_artist(karaoke_type: 'DAM', url:)
      DamSong.create!(display_artist: artist, title: '重複影響テスト楽曲', url: 'https://example.com/dam/songs/duplicate-impact')

      assert_empty DuplicateImpactReporter.new.dam_artist_url_impacts
      assert_equal 1, DamArtistUrl.where(url:).count
    end
  end
end
