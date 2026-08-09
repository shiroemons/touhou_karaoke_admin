require 'test_helper'

module DataIntegrity
  class SongDuplicateReconcilerTest < ActiveSupport::TestCase
    Checker = Struct.new(:responses) do
      def check_url(url)
        responses.fetch(url)
      end
    end

    KARAOKE_TYPE = 'JOYSOUND(うたスキ)'.freeze

    test 'dry run reports a safe duplicate without changing records' do
      records = build_duplicate_records
      resolver = resolver_for(records.fetch(:old_url), records.fetch(:new_url))

      result = SongDuplicateReconciler.new(
        scope: Song.where(id: [records.fetch(:canonical).id, records.fetch(:duplicate).id]),
        dry_run: true,
        artist_resolver: resolver
      ).call

      assert_equal 1, result.fetch(:checked)
      assert_equal 1, result.fetch(:songs_to_delete)
      assert_equal 1, result.fetch(:artists_to_update)
      assert_equal 1, result.fetch(:orphan_artists_to_delete)
      assert_equal 2, Song.where(url: records.fetch(:song_url), title: records.fetch(:title)).count
      assert_equal records.fetch(:old_url), records.fetch(:canonical).display_artist.reload.url
      assert DisplayArtist.exists?(records.fetch(:duplicate_artist).id)
    end

    test 'reconciles the duplicate, merges associations, and updates the existing artist url' do
      records = build_duplicate_records
      delivery_model = create_delivery_model(karaoke_type: KARAOKE_TYPE)
      records.fetch(:duplicate).songs_karaoke_delivery_models.create!(karaoke_delivery_model: delivery_model)
      original_song = create_original_song
      records.fetch(:duplicate).songs_original_songs.create!(original_song:)
      resolver = resolver_for(records.fetch(:old_url), records.fetch(:new_url))

      result = SongDuplicateReconciler.new(
        scope: Song.where(id: [records.fetch(:canonical).id, records.fetch(:duplicate).id]),
        dry_run: false,
        artist_resolver: resolver
      ).call

      assert_equal :reconciled, result.fetch(:groups).first.fetch(:status), result.inspect
      assert_equal 1, result.fetch(:songs_deleted)
      assert_equal 1, Song.where(url: records.fetch(:song_url), title: records.fetch(:title)).count
      assert_equal records.fetch(:new_url), records.fetch(:canonical).reload.display_artist.url
      assert_includes records.fetch(:canonical).reload.karaoke_delivery_model_ids, delivery_model.id
      assert_includes records.fetch(:canonical).reload.original_songs.map(&:id), original_song.id
      assert_not Song.exists?(records.fetch(:duplicate).id)
      assert_not DisplayArtist.exists?(records.fetch(:duplicate_artist).id)
    end

    test 'does not delete a duplicate when the canonical artist url is still valid' do
      records = build_duplicate_records
      resolver = JoysoundDisplayArtistResolver.new(
        url_checker: Checker.new(
          { records.fetch(:old_url) => { exists: true, status_code: 200, should_retry: false } }
        )
      )

      result = SongDuplicateReconciler.new(
        scope: Song.where(id: [records.fetch(:canonical).id, records.fetch(:duplicate).id]),
        dry_run: false,
        artist_resolver: resolver
      ).call

      assert_equal :skipped, result.fetch(:groups).first.fetch(:status)
      assert_equal 2, Song.where(url: records.fetch(:song_url), title: records.fetch(:title)).count
      assert_equal records.fetch(:old_url), records.fetch(:canonical).display_artist.reload.url
    end

    private

    def build_duplicate_records
      title = "重複整理テスト #{SecureRandom.hex(4)}"
      song_url = ''
      old_url = "https://example.com/joysound/artists/#{SecureRandom.hex(8)}"
      new_url = "https://example.com/joysound/artists/#{SecureRandom.hex(8)}"
      name = "重複整理アーティスト #{SecureRandom.hex(4)}"
      canonical_artist = create_display_artist(karaoke_type: KARAOKE_TYPE, name:, url: old_url)
      duplicate_artist = DisplayArtist.new(karaoke_type: KARAOKE_TYPE, name:, url: new_url)
      duplicate_artist.save!(validate: false)
      canonical = create_song(display_artist: canonical_artist, karaoke_type: KARAOKE_TYPE, title:, url: song_url)
      SongWithJoysoundUtasuki.create!(song: canonical, url: "https://example.com/music-post/#{SecureRandom.hex(8)}", delivery_deadline_date: Date.current)
      duplicate = Song.new(display_artist: duplicate_artist, karaoke_type: KARAOKE_TYPE, title:, url: song_url)
      duplicate.save!(validate: false)

      {
        canonical:,
        duplicate:,
        duplicate_artist:,
        old_url:,
        new_url:,
        song_url:,
        title:
      }
    end

    def resolver_for(old_url, new_url)
      JoysoundDisplayArtistResolver.new(
        url_checker: Checker.new(
          {
            old_url => { exists: false, status_code: 404, should_retry: false },
            new_url => { exists: true, status_code: 200, should_retry: false }
          }
        )
      )
    end
  end
end
