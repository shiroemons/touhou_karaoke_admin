require 'test_helper'

class OriginalTest < ActiveSupport::TestCase
  test 'defines supported original types' do
    assert_equal %w[pc98 windows zuns_music_collection akyus_untouched_score commercial_books other], Original.original_types.keys
  end

  test 'orders original songs by track number' do
    original = create_original
    third = create_original_song(original:, title: '3曲目', track_number: 3)
    first = create_original_song(original:, title: '1曲目', track_number: 1)
    second = create_original_song(original:, title: '2曲目', track_number: 2)

    assert_equal [first, second, third], original.original_songs.to_a
  end

  test 'destroys dependent original songs' do
    original = create_original
    create_original_song(original:)

    assert_difference -> { OriginalSong.count }, -1 do
      original.destroy!
    end
  end

  test 'exposes title as searchable attribute' do
    assert_equal ['title'], Original.ransackable_attributes
  end
end
