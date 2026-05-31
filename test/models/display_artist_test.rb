require 'test_helper'

class DisplayArtistTest < ActiveSupport::TestCase
  FakeNetwork = Struct.new(:cleared) do
    def wait_for_idle(duration: nil); end

    def clear(_type)
      self.cleared = true
    end
  end

  FakeBrowser = Struct.new(:pages, :current_url, :network, :quit_called, keyword_init: true) do
    def goto(url)
      self.current_url = url
      pages.fetch(url)
    end

    def at_css(selector)
      return FakeBodyNode.new(pages.fetch(current_url).fetch(:body)) if selector == 'body'

      nil
    end

    def css(selector)
      return pages.fetch(current_url).fetch(:links, []) if selector == 'a[href^="/web/search/artist/"]'
      return pages.fetch(current_url).fetch(:paragraphs, []).map { |paragraph| FakeBodyNode.new(paragraph) } if selector == 'main section p'

      []
    end

    def quit
      self.quit_called = true
    end
  end

  FakeBodyNode = Struct.new(:text) do
    def inner_text
      text
    end
  end

  FakeArtistLink = Struct.new(:href, :text, :paragraphs) do
    def attribute(name)
      href if name == 'href'
    end

    def css(selector)
      return paragraphs.map { |paragraph| FakeBodyNode.new(paragraph) } if selector == 'p'

      []
    end

    def inner_text
      text
    end
  end

  test 'owns circles songs and dam songs' do
    artist = create_display_artist
    circle = Circle.create!(name: '関連サークル')
    song = create_song(display_artist: artist)
    dam_song = DamSong.create!(display_artist: artist, title: 'DAM曲', url: 'https://example.com/dam/song')
    artist.circles << circle

    assert_equal [circle], artist.circles.to_a
    assert_equal [song], artist.songs.to_a
    assert_equal [dam_song], artist.dam_songs.to_a
  end

  test 'orders circles by first linked time' do
    artist = create_display_artist
    later_circle = Circle.create!(name: '後から紐づけ')
    earlier_circle = Circle.create!(name: '先に紐づけ')

    DisplayArtistsCircle.create!(display_artist: artist, circle: later_circle, created_at: 1.day.ago)
    DisplayArtistsCircle.create!(display_artist: artist, circle: earlier_circle, created_at: 2.days.ago)

    assert_equal [earlier_circle, later_circle], artist.reload.circles.to_a
  end

  test 'destroys dependent records' do
    artist = create_display_artist
    circle = Circle.create!(name: '関連サークル')
    create_song(display_artist: artist)
    DamSong.create!(display_artist: artist, title: 'DAM曲', url: 'https://example.com/dam/song')
    artist.circles << circle

    assert_difference -> { Song.count }, -1 do
      assert_difference -> { DamSong.count }, -1 do
        assert_difference -> { DisplayArtistsCircle.count }, -1 do
          artist.destroy!
        end
      end
    end

    assert Circle.exists?(circle.id)
  end

  test 'filters by karaoke type scopes' do
    dam = create_display_artist(karaoke_type: 'DAM', name: 'DAM Artist')
    joysound = create_display_artist(karaoke_type: 'JOYSOUND', name: 'JOYSOUND Artist')
    music_post = create_display_artist(karaoke_type: 'JOYSOUND(うたスキ)', name: 'Music Post Artist')

    assert_includes DisplayArtist.dam, dam
    assert_not_includes DisplayArtist.dam, joysound
    assert_includes DisplayArtist.joysound, joysound
    assert_includes DisplayArtist.music_post, music_post
  end

  test 'filters empty name readings' do
    empty = create_display_artist(name_reading: '')
    filled = create_display_artist(name_reading: 'ずん')

    assert_includes DisplayArtist.name_reading_empty, empty
    assert_not_includes DisplayArtist.name_reading_empty, filled
  end

  test 'exposes name as searchable attribute and calculates progress' do
    assert_equal ['name'], DisplayArtist.ransackable_attributes
    assert_equal 96, DisplayArtist.progress_percentage(0, 0)
    assert_equal 52, DisplayArtist.progress_percentage(5, 10)
  end

  test 'registers exact joysound music post artist from next js search result and removes missing artist' do
    artist_name = "Exact Music Post Artist #{SecureRandom.hex(4)}"
    missing_artist_name = "Missing Music Post Artist #{SecureRandom.hex(4)}"
    JoysoundMusicPost.create!(
      artist: artist_name,
      title: '登録対象曲',
      producer: 'producer',
      delivery_deadline_on: 1.month.from_now.to_date,
      url: "https://musicpost.example/#{SecureRandom.hex(4)}"
    )
    JoysoundMusicPost.create!(
      artist: missing_artist_name,
      title: '削除対象曲',
      producer: 'producer',
      delivery_deadline_on: 1.month.from_now.to_date,
      url: "https://musicpost.example/#{SecureRandom.hex(4)}"
    )

    artist_path = '/web/search/artist/357046'
    artist_url = DisplayArtist.absolute_joysound_url(artist_path)
    pages = {
      DisplayArtist.joysound_artist_search_url(artist_name) => {
        body: "#{artist_name}を含む検索結果",
        links: [
          FakeArtistLink.new(artist_path, "新曲あり#{artist_name}", [artist_name]),
          FakeArtistLink.new('/web/search/artist/999999', '別アーティスト', ['別アーティスト'])
        ]
      },
      artist_url => {
        body: "#{artist_name}\n(イグザクトミュージックポストアーティスト)\n歌手情報",
        paragraphs: ['(イグザクトミュージックポストアーティスト)'],
        links: []
      },
      DisplayArtist.joysound_artist_search_url(missing_artist_name) => {
        body: '「該当データがありません」',
        links: []
      }
    }
    browser = FakeBrowser.new(pages:, network: FakeNetwork.new)

    original_browser_new = Ferrum::Browser.method(:new)
    Ferrum::Browser.define_singleton_method(:new) { |*_args, **_kwargs| browser }
    begin
      assert_difference -> { DisplayArtist.music_post.count }, 1 do
        assert_difference -> { JoysoundMusicPost.count }, -1 do
          DisplayArtist.register_joysound_music_post_artists
        end
      end
    ensure
      Ferrum::Browser.define_singleton_method(:new) do |*args, **kwargs, &block|
        original_browser_new.call(*args, **kwargs, &block)
      end
    end

    registered_artist = DisplayArtist.music_post.find_by!(name: artist_name)
    assert_equal artist_url, registered_artist.url
    assert_equal 'イグザクトミュージックポストアーティスト', registered_artist.name_reading
    assert JoysoundMusicPost.exists?(artist: artist_name)
    assert_not JoysoundMusicPost.exists?(artist: missing_artist_name)
    assert browser.quit_called
  end
end
