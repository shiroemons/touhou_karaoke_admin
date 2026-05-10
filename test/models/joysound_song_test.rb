require 'test_helper'

class JoysoundSongTest < ActiveSupport::TestCase
  FakeNode = Struct.new(:content, :children) do
    def at_css(selector)
      children.fetch(selector, nil)
    end

    def inner_text
      content
    end

    def text
      content
    end
  end

  FakeBrowser = Struct.new(:body) do
    def at_css(selector)
      body if selector == 'body'
    end
  end

  test 'requires display title and url' do
    song = JoysoundSong.new

    assert_not song.valid?
    assert song.errors.added?(:display_title, :blank)
    assert song.errors.added?(:url, :blank)
  end

  test 'filters enabled service flags' do
    smartphone = JoysoundSong.create!(display_title: 'スマホ曲', url: 'https://example.com/joysound/smartphone', smartphone_service_enabled: true)
    home = JoysoundSong.create!(display_title: '家庭用曲', url: 'https://example.com/joysound/home', home_karaoke_enabled: true)
    disabled = JoysoundSong.create!(display_title: '無効曲', url: 'https://example.com/joysound/disabled')

    assert_includes JoysoundSong.enabled_smartphone_service, smartphone
    assert_not_includes JoysoundSong.enabled_smartphone_service, disabled
    assert_includes JoysoundSong.enabled_home_karaoke, home
    assert_not_includes JoysoundSong.enabled_home_karaoke, disabled
  end

  test 'adds enabled delivery models to matching registered songs' do
    artist = create_display_artist(karaoke_type: 'JOYSOUND')
    song = create_song(display_artist: artist, karaoke_type: 'JOYSOUND', title: '配信曲', url: 'https://example.com/joysound/linked')
    smartphone = create_delivery_model(karaoke_type: 'JOYSOUND', name: 'スマホサービス')
    home = create_delivery_model(karaoke_type: 'JOYSOUND', name: '家庭用カラオケ')
    JoysoundSong.create!(
      display_title: '配信曲／ZUN',
      url: song.url,
      smartphone_service_enabled: true,
      home_karaoke_enabled: true
    )

    assert_difference -> { SongsKaraokeDeliveryModel.count }, 2 do
      JoysoundSong.add_delivery_model
    end

    assert_equal [home, smartphone].sort_by(&:id), song.reload.karaoke_delivery_models.sort_by(&:id)
  end

  test 'builds display title from title and artist nodes' do
    link = FakeNode.new(nil, {
                          'p' => FakeNode.new('曲名', {}),
                          'div.font-medium' => FakeNode.new('歌手', {})
                        })

    assert_equal '曲名／歌手', JoysoundSong.joysound_display_title(link)
  end

  test 'detects total pages from joysound result count' do
    browser = FakeBrowser.new(FakeNode.new('曲一覧(1,234件)', {}))

    assert_equal 62, JoysoundSong.detect_joysound_search_total_pages(browser, 20)
    assert_nil JoysoundSong.detect_joysound_search_total_pages(browser, 0)
  end

  test 'calculates bounded touhou fetch progress' do
    assert_equal 8, JoysoundSong.joysound_touhou_progress_percentage(page: 1, item_index: 0, item_count: 20, total_pages: 2)
    assert_equal 52, JoysoundSong.joysound_touhou_progress_percentage(page: 2, item_index: 0, item_count: 20, total_pages: 2)
    assert_equal 96, JoysoundSong.joysound_touhou_progress_percentage(page: 2, item_index: 20, item_count: 20, total_pages: 2)
  end

  test 'exposes display title as searchable attribute' do
    assert_equal ['display_title'], JoysoundSong.ransackable_attributes
  end
end
