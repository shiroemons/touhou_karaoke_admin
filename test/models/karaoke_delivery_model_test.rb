require 'test_helper'

class KaraokeDeliveryModelTest < ActiveSupport::TestCase
  test 'requires name and karaoke type' do
    model = KaraokeDeliveryModel.new(order: 1)

    assert_not model.valid?
    assert model.errors.added?(:name, :blank)
    assert model.errors.added?(:karaoke_type, :blank)
  end

  test 'enforces name uniqueness per karaoke type' do
    name = "Unique Model #{SecureRandom.hex(4)}"
    create_delivery_model(name:, karaoke_type: 'DAM')

    duplicate = KaraokeDeliveryModel.new(name:, karaoke_type: 'DAM', order: 999)
    same_name_other_type = KaraokeDeliveryModel.new(name:, karaoke_type: 'JOYSOUND', order: 1000)

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:name, :taken, value: name)
    assert same_name_other_type.valid?
  end

  test 'uses list order as implicit order column' do
    assert_equal 'order', KaraokeDeliveryModel.implicit_order_column

    second = create_delivery_model(name: 'Order B', order: 20)
    first = create_delivery_model(name: 'Order A', order: 10)
    assert_equal [first, second], KaraokeDeliveryModel.where(id: [first.id, second.id]).order(:order).to_a
  end

  test 'exposes name and karaoke type as searchable attributes' do
    assert_equal %w[name karaoke_type], KaraokeDeliveryModel.ransackable_attributes
  end
end
