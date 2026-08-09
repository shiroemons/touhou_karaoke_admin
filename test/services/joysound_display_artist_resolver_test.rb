require 'test_helper'

class JoysoundDisplayArtistResolverTest < ActiveSupport::TestCase
  Checker = Struct.new(:responses) do
    def check_url(url)
      responses.fetch(url)
    end
  end

  KARAOKE_TYPE = 'JOYSOUND(うたスキ)'.freeze

  test 'updates an existing artist when the old url is not found and the new url exists' do
    old_url = 'https://example.com/joysound/artists/old'
    new_url = 'https://example.com/joysound/artists/new'
    artist = create_display_artist(karaoke_type: KARAOKE_TYPE, name: 'URL変更アーティスト', url: old_url)
    song = create_song(display_artist: artist, karaoke_type: KARAOKE_TYPE)
    resolver = resolver_for(
      old_url => { exists: false, status_code: 404, should_retry: false },
      new_url => { exists: true, status_code: 200, should_retry: false }
    )

    result = resolver.resolve(name: artist.name, karaoke_type: KARAOKE_TYPE, url: new_url, existing_song: song)

    assert_equal :updated_url, result.action
    assert_equal new_url, artist.reload.url
  end

  test 'does not update an existing artist while the old url is still valid' do
    old_url = 'https://example.com/joysound/artists/valid'
    new_url = 'https://example.com/joysound/artists/other'
    artist = create_display_artist(karaoke_type: KARAOKE_TYPE, name: '有効URLアーティスト', url: old_url)
    resolver = resolver_for(old_url => { exists: true, status_code: 200, should_retry: false })

    result = resolver.resolve(name: artist.name, karaoke_type: KARAOKE_TYPE, url: new_url)

    assert_equal :skipped, result.action
    assert_equal :old_url_still_valid, result.reason
    assert_equal old_url, artist.reload.url
  end

  test 'does not update an existing artist when the old url cannot be verified' do
    old_url = 'https://example.com/joysound/artists/unverified'
    new_url = 'https://example.com/joysound/artists/new-unverified'
    artist = create_display_artist(karaoke_type: KARAOKE_TYPE, name: '未確認URLアーティスト', url: old_url)
    resolver = resolver_for(old_url => { exists: nil, should_retry: true })

    result = resolver.resolve(name: artist.name, karaoke_type: KARAOKE_TYPE, url: new_url)

    assert_equal :skipped, result.action
    assert_equal :old_url_unverified, result.reason
    assert_equal old_url, artist.reload.url
  end

  test 'does not update an existing artist when the new url is invalid' do
    old_url = 'https://example.com/joysound/artists/missing-old'
    new_url = 'https://example.com/joysound/artists/missing-new'
    artist = create_display_artist(karaoke_type: KARAOKE_TYPE, name: '新URL無効アーティスト', url: old_url)
    resolver = resolver_for(
      old_url => { exists: false, status_code: 404, should_retry: false },
      new_url => { exists: false, status_code: 404, should_retry: false }
    )

    result = resolver.resolve(name: artist.name, karaoke_type: KARAOKE_TYPE, url: new_url)

    assert_equal :skipped, result.action
    assert_equal :new_url_invalid, result.reason
    assert_equal old_url, artist.reload.url
  end

  test 'reuses the existing artist when resolving a new song with the same name' do
    old_url = 'https://example.com/joysound/artists/reused-old'
    new_url = 'https://example.com/joysound/artists/reused-new'
    artist = create_display_artist(karaoke_type: KARAOKE_TYPE, name: '再利用アーティスト', url: old_url)
    resolver = resolver_for(
      old_url => { exists: false, status_code: 410, should_retry: false },
      new_url => { exists: true, status_code: 200, should_retry: false }
    )

    assert_no_difference -> { DisplayArtist.count } do
      result = resolver.resolve(name: artist.name, karaoke_type: KARAOKE_TYPE, url: new_url)

      assert_equal artist.id, result.artist.id
      assert_equal :updated_url, result.action
    end
  end

  test 'rejects an existing song whose artist name changed' do
    artist = create_display_artist(karaoke_type: KARAOKE_TYPE, name: '既存アーティスト')
    song = create_song(display_artist: artist, karaoke_type: KARAOKE_TYPE)
    resolver = resolver_for

    assert_raises(JoysoundDisplayArtistResolver::Conflict) do
      resolver.resolve(name: '別アーティスト', karaoke_type: KARAOKE_TYPE, url: 'https://example.com/new', existing_song: song)
    end
  end

  private

  def resolver_for(*pairs)
    responses = pairs.length == 1 && pairs.first.is_a?(Hash) ? pairs.first : pairs.to_h
    JoysoundDisplayArtistResolver.new(url_checker: Checker.new(responses))
  end
end
