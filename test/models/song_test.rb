require 'test_helper'

class SongTest < ActiveSupport::TestCase
  test 'owns delivery models original songs and optional service details' do
    artist = create_display_artist
    song = create_song(display_artist: artist)
    delivery_model = create_delivery_model
    original_song = create_original_song
    dam_detail = SongWithDamOuchikaraoke.create!(song:, url: 'https://example.com/dam/ouchikaraoke')
    joysound_detail = SongWithJoysoundUtasuki.create!(song:, url: 'https://example.com/joysound/utasuki', delivery_deadline_date: Date.current)

    song.karaoke_delivery_models << delivery_model
    song.original_songs << original_song

    assert_equal artist, song.display_artist
    assert_equal [delivery_model], song.karaoke_delivery_models.to_a
    assert_equal [original_song], song.original_songs.to_a
    assert_equal dam_detail, song.song_with_dam_ouchikaraoke
    assert_equal joysound_detail, song.song_with_joysound_utasuki
  end

  test 'destroys dependent join and detail records' do
    song = create_song
    song.karaoke_delivery_models << create_delivery_model
    song.original_songs << create_original_song
    SongWithDamOuchikaraoke.create!(song:, url: 'https://example.com/dam/ouchikaraoke')
    SongWithJoysoundUtasuki.create!(song:, url: 'https://example.com/joysound/utasuki', delivery_deadline_date: Date.current)

    assert_difference -> { SongsKaraokeDeliveryModel.count }, -1 do
      assert_difference -> { SongsOriginalSong.count }, -1 do
        assert_difference -> { SongWithDamOuchikaraoke.count }, -1 do
          assert_difference -> { SongWithJoysoundUtasuki.count }, -1 do
            song.destroy!
          end
        end
      end
    end
  end

  test 'filters by karaoke and service scopes' do
    dam = create_song(karaoke_type: 'DAM', youtube_url: 'https://youtube.example/watch')
    joysound = create_song(display_artist: create_display_artist(karaoke_type: 'JOYSOUND'), karaoke_type: 'JOYSOUND', spotify_url: 'https://spotify.example/track')
    music_post = create_song(display_artist: create_display_artist(karaoke_type: 'JOYSOUND(うたスキ)'), karaoke_type: 'JOYSOUND(うたスキ)', line_music_url: 'https://line.example/song')

    assert_includes Song.dam, dam
    assert_includes Song.joysound, joysound
    assert_includes Song.music_post, music_post
    assert_includes Song.youtube, dam
    assert_includes Song.spotify, joysound
    assert_includes Song.line_music, music_post
  end

  test 'classifies original song link state and category' do
    touhou = create_song(title: '東方アレンジ')
    touhou.original_songs << create_original_song(title: '赤より紅い夢')
    original = create_song(title: 'オリジナル曲')
    original.original_songs << create_original_song(title: 'オリジナル')
    missing = create_song(title: '未紐付け')

    assert_equal 'あり', touhou.original_songs_link_status
    assert_equal '1曲', touhou.original_songs_count_label
    assert_equal '東方アレンジ', touhou.original_song_category_label
    assert touhou.touhou?
    assert_equal 'オリジナル・その他', original.original_song_category_label
    assert_equal 'なし', missing.original_songs_link_status
    assert_equal '未紐付け', missing.original_song_category_label
  end

  test 'filters original song category scopes without duplicates' do
    touhou = create_song(title: '東方アレンジ')
    touhou.original_songs << create_original_song(title: '赤より紅い夢')
    touhou.original_songs << create_original_song(title: 'U.N.オーエンは彼女なのか？')
    original = create_song(title: 'オリジナル曲')
    original.original_songs << create_original_song(title: 'オリジナル')
    missing = create_song(title: '未紐付け')

    assert_equal [missing], Song.missing_original_songs.where(id: [touhou.id, original.id, missing.id]).to_a
    assert_equal [touhou.id], Song.touhou_arrange.where(id: [touhou.id, original.id, missing.id]).pluck(:id)
    assert_equal [original.id], Song.original_or_other.where(id: [touhou.id, original.id, missing.id]).pluck(:id)
  end

  test 'prioritizes unmatched and near-deadline music posts once' do
    matched_song = create_song(display_artist: create_display_artist(karaoke_type: 'JOYSOUND(うたスキ)'), karaoke_type: 'JOYSOUND(うたスキ)', url: 'https://example.com/matched')
    JoysoundMusicPost.create!(title: 'Matched', artist: 'ZUN', producer: 'p', delivery_deadline_on: 2.months.from_now.to_date, url: 'https://example.com/post/matched', joysound_url: matched_song.url)
    unmatched = JoysoundMusicPost.create!(title: 'Unmatched', artist: 'ZUN', producer: 'p', delivery_deadline_on: 2.months.from_now.to_date, url: 'https://example.com/post/unmatched', joysound_url: 'https://example.com/unmatched')
    upcoming = JoysoundMusicPost.create!(title: 'Upcoming', artist: 'ZUN', producer: 'p', delivery_deadline_on: 1.week.from_now.to_date, url: 'https://example.com/post/upcoming', joysound_url: 'https://example.com/upcoming')

    result = Song.prioritized_joysound_music_posts

    assert_includes result, unmatched
    assert_includes result, upcoming
    assert_equal result.uniq, result
  end

  test 'exposes title as searchable attribute' do
    assert_equal ['title'], Song.ransackable_attributes
  end
end
