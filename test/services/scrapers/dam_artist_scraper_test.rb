# frozen_string_literal: true

require 'test_helper'

module Scrapers
  class DamArtistScraperTest < ActiveSupport::TestCase
    class FailingBrowser
      attr_reader :quit_called

      def goto(_url)
        raise 'timeout'
      end

      def quit
        @quit_called = true
      end
    end

    test 'closes browser for every failed artist parser attempt' do
      browsers = []
      original_browser_new = Ferrum::Browser.method(:new)
      Ferrum::Browser.define_singleton_method(:new) do |*_args, **_kwargs|
        FailingBrowser.new.tap { |browser| browsers << browser }
      end

      DamArtistScraper.new.scrape_artist_page('https://example.com/dam/artist')

      assert_equal 4, browsers.size
      assert browsers.all?(&:quit_called)
    ensure
      Ferrum::Browser.define_singleton_method(:new, original_browser_new)
    end
  end
end
