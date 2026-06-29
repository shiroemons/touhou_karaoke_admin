require 'test_helper'

module Scrapers
  class JoysoundScraperTest < ActiveSupport::TestCase
    FakeBrowserManager = Struct.new(:buttons) do
      def find_all(selector)
        return buttons if selector == JoysoundScraper::DELIVERY_MODEL_MORE_BUTTON_SELECTOR

        []
      end
    end

    FakeButton = Struct.new(:text, :clicked) do
      def inner_text
        text
      end

      def focus
        self
      end

      def click
        self.clicked = true
      end
    end

    class ForbiddenBrowserManager
      def method_missing(method_name, ...)
        raise "HTTP-only parser must not use browser manager ##{method_name}"
      end

      def respond_to_missing?(_method_name, _include_private = false)
        true
      end
    end

    class RecordingBrowserManager
      attr_reader :calls

      def initialize
        @calls = []
      end

      def with_browser
        calls << :with_browser
        yield Object.new
      end

      def clear_network_traffic
        calls << :clear_network_traffic
      end

      def visit(url)
        calls << [:visit, url]
      end
    end

    test 'extract_delivery_models keeps only JOYSOUND model chips' do
      element = Nokogiri::HTML.fragment(<<~HTML)
        <div>
          <li>JOYSOUND X1</li>
          <li>JOYSOUND MAX GO</li>
          <li>JOYSOUND MAX2</li>
          <li>JOYSOUND MAX</li>
          <li>JOYSOUND f1</li>
          <li>JOYSOUND X1</li>
          <li>JOYSOUND X1</li>
          <li>JOYSOUND 響Ⅱ</li>
          <li>※JOYSOUND X1...主にスナック・バー向けモデル</li>
          <li>※JOYSOUND X1...主に宴会場・老健施設向けモデル</li>
          <li>一部の楽曲を除き、全国採点、分析採点、うたスキ動画、スピードコントロール、キーコントロールなどがご利用いただけません。</li>
          <li>通信環境によって歌唱いただけない場合がございます。</li>
          <li>店舗検索結果で「うたスキ」と「うたスキ動画」両方が表示されている店舗で歌唱可能です。</li>
          <li>採点ランキングを見る</li>
        </div>
      HTML

      delivery_models = JoysoundScraper.new.send(:extract_delivery_models, element)

      assert_equal [
        'JOYSOUND X1',
        'JOYSOUND MAX GO',
        'JOYSOUND MAX2',
        'JOYSOUND MAX',
        'JOYSOUND f1',
        'JOYSOUND 響Ⅱ'
      ], delivery_models
    end

    test 'extract_delivery_models keeps legacy JOYSOUND model names' do
      element = Nokogiri::HTML.fragment(<<~HTML)
        <div>
          <li>EnjoyPortable</li>
          <li>EnjoyStage</li>
          <li>HyperJoy V2</li>
          <li>CelebJoyHearts</li>
          <li>HyperJoy Wave</li>
          <li>JEWEL</li>
          <li>CROSSO</li>
        </div>
      HTML

      delivery_models = JoysoundScraper.new.send(:extract_delivery_models, element)

      assert_equal [
        'EnjoyPortable',
        'EnjoyStage',
        'HyperJoy V2',
        'CelebJoyHearts',
        'HyperJoy Wave',
        'JEWEL',
        'CROSSO'
      ], delivery_models
    end

    test 'expand_delivery_model_sections clicks current JOYSOUND other button' do
      other_button = FakeButton.new('その他', false)
      ignored_button = FakeButton.new('歌詞を見る', false)
      scraper = JoysoundScraper.new
      scraper.instance_variable_set(:@browser_manager, FakeBrowserManager.new([other_button, ignored_button]))

      scraper.send(:expand_delivery_model_sections)

      assert other_button.clicked
      assert_not ignored_button.clicked
    end

    test 'HTTP-only delivery model extraction does not use browser manager' do
      element = Nokogiri::HTML.fragment(<<~HTML)
        <div>
          <li>JOYSOUND X1</li>
          <li>採点ランキングを見る</li>
        </div>
      HTML
      scraper = JoysoundScraper.new(browser_manager: ForbiddenBrowserManager.new)

      assert_equal ['JOYSOUND X1'], scraper.send(:extract_delivery_models, element)
    end

    test 'dynamic JOYSOUND song page scraping uses browser manager' do
      browser_manager = RecordingBrowserManager.new
      scraper = JoysoundScraper.new(browser_manager:)
      scraper.define_singleton_method(:song_information) { { '作曲' => 'テスト作曲者' } }

      scraper.scrape_song_page('https://www.joysound.com/web/search/song/1')

      assert_equal [
        :with_browser,
        :clear_network_traffic,
        [:visit, 'https://www.joysound.com/web/search/song/1']
      ], browser_manager.calls
    end
  end
end
