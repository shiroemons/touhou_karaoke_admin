require 'test_helper'

class SongsKaraokeDeliveryModelTest < ActiveSupport::TestCase
  test 'requires song and delivery model' do
    join = SongsKaraokeDeliveryModel.new

    assert_not join.valid?
    assert_not_empty join.errors[:song]
    assert_not_empty join.errors[:karaoke_delivery_model]
  end

  test 'prevents duplicate song and delivery model links' do
    song = create_song
    delivery_model = create_delivery_model
    SongsKaraokeDeliveryModel.create!(song:, karaoke_delivery_model: delivery_model)
    duplicate = SongsKaraokeDeliveryModel.new(song:, karaoke_delivery_model: delivery_model)

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:song_id, :taken, value: song.id)
  end

  test 'finds existing association instead of creating duplicates' do
    song = create_song
    delivery_model = create_delivery_model

    assert_difference -> { SongsKaraokeDeliveryModel.count }, 1 do
      SongsKaraokeDeliveryModel.find_or_create_association(song.id, delivery_model.id)
    end
    assert_no_difference -> { SongsKaraokeDeliveryModel.count } do
      SongsKaraokeDeliveryModel.find_or_create_association(song.id, delivery_model.id)
    end
  end

  test 'creates unique associations safely in batch' do
    song = create_song
    first = create_delivery_model
    second = create_delivery_model

    created = SongsKaraokeDeliveryModel.create_associations_safely(song.id, [first.id, second.id, first.id])

    assert_equal 2, created.compact.uniq(&:karaoke_delivery_model_id).size
    assert_equal [first.id, second.id].sort, song.reload.karaoke_delivery_model_ids.sort
  end
end
