require 'test_helper'

class DeliveryModelValidatorTest < ActiveSupport::TestCase
  setup do
    @validator = DeliveryModelValidator.new
  end

  test 'normalizes blank full width and repeated whitespace' do
    assert_nil @validator.normalize_name(nil)
    assert_nil @validator.normalize_name('')
    assert_equal 'JOYSOUND MAX GO', @validator.normalize_name("　JOYSOUND\tMAX  GO　")
  end

  test 'detects duplicates after normalization' do
    name = "JOYSOUND MAX GO #{SecureRandom.hex(4)}"
    create_delivery_model(name:, karaoke_type: 'JOYSOUND')

    assert @validator.duplicate_exists?(" #{name} ", 'JOYSOUND')
    assert_not @validator.duplicate_exists?(name, 'DAM')
  end

  test 'finds existing model before creating a duplicate' do
    name = "LIVE DAM AiR #{SecureRandom.hex(4)}"
    existing = create_delivery_model(name:, karaoke_type: 'DAM')

    assert_no_difference -> { KaraokeDeliveryModel.count } do
      assert_equal existing, @validator.find_or_create_safely(" #{name} ", 'DAM')
    end
  end

  test 'creates normalized models and skips blank names' do
    assert_no_difference -> { KaraokeDeliveryModel.count } do
      assert_nil @validator.find_or_create_safely('   ', 'DAM')
    end

    assert_difference -> { KaraokeDeliveryModel.count }, 1 do
      model = @validator.find_or_create_safely('　新機種　', 'DAM')
      assert_equal '新機種', model.name
    end
  end

  test 'normalizes existing records without creating duplicates' do
    normalize_target = create_delivery_model(name: '　正規化 対象　', karaoke_type: 'DAM')
    duplicate_target = create_delivery_model(name: '重複対象', karaoke_type: 'DAM')
    duplicate_source = create_delivery_model(name: '　重複対象　', karaoke_type: 'DAM')

    assert_equal 1, @validator.normalize_existing_records
    assert_equal '正規化 対象', normalize_target.reload.name
    assert_equal '重複対象', duplicate_target.reload.name
    assert_equal '　重複対象　', duplicate_source.reload.name
  end
end
