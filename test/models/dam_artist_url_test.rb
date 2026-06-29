require 'test_helper'

class DamArtistUrlTest < ActiveSupport::TestCase
  test 'requires url' do
    record = DamArtistUrl.new(url: '')

    assert_not record.valid?
    assert record.errors.added?(:url, :blank)
  end

  test 'requires unique url' do
    existing = DamArtistUrl.create!(url: 'https://example.com/dam/artists/unique')
    duplicate = DamArtistUrl.new(url: existing.url)

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:url, :taken, value: existing.url)
  end

  test 'exposes only url as searchable attribute' do
    assert_equal ['url'], DamArtistUrl.ransackable_attributes
  end

  test 'calculates bounded progress percentage' do
    assert_equal 96, DamArtistUrl.progress_percentage(0, 0)
    assert_equal 8, DamArtistUrl.progress_percentage(0, 10)
    assert_equal 52, DamArtistUrl.progress_percentage(5, 10)
    assert_equal 96, DamArtistUrl.progress_percentage(10, 10)
    assert_equal 96, DamArtistUrl.progress_percentage(20, 10)
  end

  test 'delegates artist page parsing to scraper service' do
    calls = []
    scraper = Object.new
    scraper.define_singleton_method(:scrape_artist_page) { |url| calls << url }
    original_new = Scrapers::DamArtistScraper.method(:new)
    Scrapers::DamArtistScraper.define_singleton_method(:new) { scraper }

    DamArtistUrl.dam_artist_page_parser('https://example.com/dam/artist')

    assert_equal ['https://example.com/dam/artist'], calls
  ensure
    Scrapers::DamArtistScraper.define_singleton_method(:new, original_new)
  end
end
