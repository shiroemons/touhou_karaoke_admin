require 'test_helper'

class JoysoundMusicPostTest < ActiveSupport::TestCase
  test 'requires core music post attributes' do
    post = JoysoundMusicPost.new

    assert_not post.valid?
    assert post.errors.added?(:title, :blank)
    assert post.errors.added?(:artist, :blank)
    assert post.errors.added?(:producer, :blank)
    assert post.errors.added?(:delivery_deadline_on, :blank)
    assert post.errors.added?(:url, :blank)
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
end
