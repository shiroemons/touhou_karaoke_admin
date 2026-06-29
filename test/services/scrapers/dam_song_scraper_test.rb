# frozen_string_literal: true

require 'test_helper'

module Scrapers
  class DamSongScraperTest < ActiveSupport::TestCase
    class FailingBrowser
      attr_reader :quit_called

      def goto(_url)
        raise 'navigation failed'
      end

      def quit
        @quit_called = true
      end
    end

    class FakeBrowserManager
      attr_reader :browser

      def initialize(browser)
        @browser = browser
      end

      def with_browser
        yield(browser)
      ensure
        browser.quit
      end
    end

    test 'closes browser for every failed artist song list attempt' do
      artist = create_display_artist(url: 'https://www.clubdam.com/karaokesearch/artistleaf.html?artistCode=test')
      browsers = []
      scraper = DamSongScraper.new(
        browser_manager_factory: lambda do |_options|
          browser = FailingBrowser.new
          browsers << browser
          FakeBrowserManager.new(browser)
        end
      )

      scraper.parse_artist_song_list(artist)

      assert_equal 4, browsers.size
      assert browsers.all?(&:quit_called)
    end
  end
end
