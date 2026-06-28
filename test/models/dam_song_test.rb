require 'test_helper'

class DamSongTest < ActiveSupport::TestCase
  FakeNode = Struct.new(:text, :href) do
    def attribute(name)
      href if name == 'href'
    end

    def inner_text
      text
    end
  end

  FakeBrowser = Struct.new(:links, :body) do
    def css(selector)
      return links if selector == 'a[href*="pageNo="]'

      []
    end

    def at_css(selector)
      body if selector == 'body'
    end
  end

  FailingBrowser = Struct.new(:quit_called, keyword_init: true) do
    def network
      self
    end

    def goto(_url); end

    def wait_for_idle(duration:); end

    def css(_selector)
      raise Ferrum::NodeNotFoundError, 'missing list'
    end

    def at_css(_selector)
      raise Ferrum::NodeNotFoundError, 'missing selector'
    end

    def quit
      self.quit_called = true
    end
  end

  test 'belongs to display artist' do
    artist = create_display_artist
    song = DamSong.create!(display_artist: artist, title: 'DAM曲', url: 'https://example.com/dam/song')

    assert_equal artist, song.display_artist
  end

  test 'requires core attributes and unique url' do
    artist = create_display_artist
    existing = DamSong.create!(display_artist: artist, title: 'DAM曲', url: 'https://example.com/dam/songs/unique')
    duplicate = DamSong.new(display_artist: artist, title: '別DAM曲', url: existing.url)
    blank = DamSong.new(display_artist: artist, title: '', url: '')

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:url, :taken, value: existing.url)
    assert_not blank.valid?
    assert blank.errors.added?(:title, :blank)
    assert blank.errors.added?(:url, :blank)
  end

  test 'exposes title as searchable attribute' do
    assert_equal ['title'], DamSong.ransackable_attributes
  end

  test 'detects total search pages from pagination links and result count' do
    links = [
      FakeNode.new(nil, '/karaoke-dam/search/?pageNo=2'),
      FakeNode.new(nil, '/karaoke-dam/search/?pageNo=5')
    ]
    browser = FakeBrowser.new(links, FakeNode.new('検索結果 350件', nil))

    assert_equal 5, DamSong.detect_dam_search_total_pages(browser, 100)
  end

  test 'closes browser when direct DAM song fetch fails' do
    browser = FailingBrowser.new(quit_called: false)
    original_browser_new = Ferrum::Browser.method(:new)
    Ferrum::Browser.define_singleton_method(:new) { |*_args, **_kwargs| browser }

    assert_raises(Ferrum::NodeNotFoundError) do
      DamSong.fetch_dam_song("#{Constants::Karaoke::Dam::SONG_URL}123456")
    end
    assert browser.quit_called
  ensure
    Ferrum::Browser.define_singleton_method(:new) do |*args, **kwargs, &block|
      original_browser_new.call(*args, **kwargs, &block)
    end
  end

  test 'calculates bounded touhou fetch progress' do
    assert_equal 8, DamSong.dam_touhou_progress_percentage(page: 1, item_index: 0, item_count: 100, total_pages: 2)
    assert_equal 52, DamSong.dam_touhou_progress_percentage(page: 2, item_index: 0, item_count: 100, total_pages: 2)
    assert_equal 96, DamSong.dam_touhou_progress_percentage(page: 2, item_index: 100, item_count: 100, total_pages: 2)
  end

  test 'closes browser for every failed DAM song list parser attempt' do
    artist = create_display_artist(karaoke_type: 'DAM', url: 'https://example.com/dam/artist')
    browsers = []
    original_browser_new = Ferrum::Browser.method(:new)
    Ferrum::Browser.define_singleton_method(:new) do |*_args, **_kwargs|
      FailingBrowser.new.tap { |browser| browsers << browser }
    end

    DamSong.dam_song_list_parser(artist)

    assert_equal 4, browsers.size
    assert browsers.all?(&:quit_called)
  ensure
    Ferrum::Browser.define_singleton_method(:new, original_browser_new)
  end
end
