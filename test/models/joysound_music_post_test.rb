require 'test_helper'

class JoysoundMusicPostTest < ActiveSupport::TestCase
  FakeJoysoundBrowser = Struct.new(:pages, :current_url, :quit_called, :screenshot_path, keyword_init: true) do
    def goto(url)
      self.current_url = url
      pages.fetch(url)
    end

    def css(selector)
      pages.fetch(current_url).fetch(selector, [])
    end

    def screenshot(path:)
      self.screenshot_path = path
    end

    def quit
      self.quit_called = true
    end
  end

  FakeJoysoundLink = Struct.new(:href, :title, :text) do
    def attribute(name)
      href if name == "href"
    end

    def css(selector)
      return [FakeJoysoundTextNode.new(title)] if selector == "h3, p"

      []
    end

    def inner_text
      text || title
    end
  end

  FakeJoysoundTextNode = Struct.new(:text) do
    def inner_text
      text
    end
  end

  TimeoutBrowser = Struct.new(:quit_called, keyword_init: true) do
    def goto(_url)
      raise Ferrum::TimeoutError, 'timeout'
    end

    def quit
      self.quit_called = true
    end
  end

  test 'requires core music post attributes' do
    post = JoysoundMusicPost.new

    assert_not post.valid?
    assert post.errors.added?(:title, :blank)
    assert post.errors.added?(:artist, :blank)
    assert post.errors.added?(:producer, :blank)
    assert post.errors.added?(:delivery_deadline_on, :blank)
    assert post.errors.added?(:url, :blank)
  end

  test 'requires unique url' do
    existing = JoysoundMusicPost.create!(
      title: '重複防止曲',
      artist: '重複防止アーティスト',
      producer: '重複防止投稿者',
      delivery_deadline_on: Date.current,
      url: 'https://musicpost.example/unique'
    )
    duplicate = JoysoundMusicPost.new(
      title: '別曲',
      artist: '別アーティスト',
      producer: '別投稿者',
      delivery_deadline_on: Date.current,
      url: existing.url
    )

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:url, :taken, value: existing.url)
  end

  test 'exposes title and artist as searchable attributes' do
    assert_equal %w[artist title], JoysoundMusicPost.ransackable_attributes
  end

  test 'calculates bounded fixed-range progress' do
    assert_equal 96, JoysoundMusicPost.progress_percentage(0, 0)
    assert_equal 8, JoysoundMusicPost.progress_percentage(0, 10)
    assert_equal 52, JoysoundMusicPost.progress_percentage(5, 10)
    assert_equal 96, JoysoundMusicPost.progress_percentage(10, 10)
  end

  test 'calculates unknown page progress inside supplied range' do
    assert_equal 8, JoysoundMusicPost.unknown_page_progress(1, 0, 10, 8..52)
    assert_equal 19, JoysoundMusicPost.unknown_page_progress(1, 5, 10, 8..52)
    assert_equal 51, JoysoundMusicPost.unknown_page_progress(99, 10, 10, 8..52)
  end

  test 'links blank music post to current joysound song list result' do
    artist = create_display_artist(
      karaoke_type: 'JOYSOUND(うたスキ)',
      name: 'Current Dom Test Artist',
      url: 'https://www.joysound.com/web/search/artist/999001'
    )
    music_post = JoysoundMusicPost.create!(
      title: 'Current DOM Test Music Post Song',
      artist: artist.name,
      producer: 'Current DOM Test Producer',
      delivery_deadline_on: 1.month.from_now.to_date,
      url: 'https://musicpost.example/music/current-dom-test',
      joysound_url: ''
    )
    search_url = "#{artist.url}?sortOrder=new&orderBy=desc&startIndex=0#songList"
    browser = FakeJoysoundBrowser.new(
      pages: {
        search_url => {
          '#songList [data-testid="card-information"] a[href^="/web/search/song/"]' => [
            FakeJoysoundLink.new('/web/search/song/999002', music_post.title)
          ],
          '#songList a[href*="page="]' => []
        }
      }
    )

    original_browser_new = Ferrum::Browser.method(:new)
    Ferrum::Browser.define_singleton_method(:new) { |*_args, **_kwargs| browser }
    begin
      JoysoundMusicPost.fetch_music_post_song_joysound_url
    ensure
      Ferrum::Browser.define_singleton_method(:new) do |*args, **kwargs, &block|
        original_browser_new.call(*args, **kwargs, &block)
      end
    end

    assert_equal 'https://www.joysound.com/web/search/song/999002', music_post.reload.joysound_url
    assert browser.quit_called
  end

  test 'closes browser for every timed out music post parser attempt' do
    browsers = []
    original_browser_new = Ferrum::Browser.method(:new)
    Ferrum::Browser.define_singleton_method(:new) do |*_args, **_kwargs|
      TimeoutBrowser.new.tap { |browser| browsers << browser }
    end

    JoysoundMusicPost.music_post_parser('https://example.com/music-post')

    assert_equal 4, browsers.size
    assert browsers.all?(&:quit_called)
  ensure
    Ferrum::Browser.define_singleton_method(:new, original_browser_new)
  end
end
