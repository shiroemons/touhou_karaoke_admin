# frozen_string_literal: true

require 'test_helper'

module Scrapers
  class SelectorFixtureTest < ActiveSupport::TestCase
    test 'DAM song detail selectors match fixture structure' do
      selectors = selector_config('dam').fetch('song_detail')
      document = fixture_document('dam_song_detail.html')

      assert_equal 'テストDAM楽曲', document.at_css(selectors.fetch('title')).text
      assert_equal '[テストダムガッキョク]', document.at_css(selectors.fetch('title_reading')).text
      assert_equal '1234-56', document.at_css(selectors.fetch('song_number')).text
      assert_equal 'LIVE DAM AiR', document.at_css(selectors.fetch('latest_model')).text
      assert_equal ['LIVE DAM STADIUM'], document.css(selectors.fetch('model_list')).map(&:text)
      assert_equal 'https://example.com/dam/ouchikaraoke', document.at_css(selectors.fetch('ouchikaraoke')).attr('href')
    end

    test 'JOYSOUND song detail selectors match fixture structure' do
      selectors = selector_config('joysound').fetch('song_detail')
      document = fixture_document('joysound_song_detail.html')
      song_block = document.at_css(selectors.fetch('songs'))
      information_labels = document.css(selectors.fetch('information_rows')).map { |row| row.at_css('th').text }

      assert_equal %w[歌手名 作曲], information_labels
      assert_equal 'ZUN', document.at_css(selectors.fetch('artist')).text
      assert_equal 'テストJOYSOUND楽曲', song_block.at_css(selectors.fetch('song_title')).text
      assert_equal ['JOYSOUND X1', '家庭用カラオケ'], song_block.css(selectors.fetch('platform_item')).map(&:text)
      assert_equal 'テストJOYSOUND楽曲 JOYSOUND X1 家庭用カラオケ', song_block.text.squish
    end

    private

    def selector_config(name)
      YAML.load_file(Rails.root.join("config/selectors/#{name}.yml")).fetch('selectors')
    end

    def fixture_document(filename)
      Nokogiri::HTML(Rails.root.join("test/fixtures/html/#{filename}").read)
    end
  end
end
