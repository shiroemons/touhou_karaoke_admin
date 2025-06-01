require 'test_helper'

class DeliveryModelManagerTest < ActiveSupport::TestCase
  setup do
    @manager = DeliveryModelManager.instance
    @manager.clear_cache

    # テストデータの準備
    @existing_model = KaraokeDeliveryModel.create!(
      name: "LIVE DAM STADIUM",
      karaoke_type: "DAM",
      order: 1
    )
  end

  teardown do
    @manager.clear_cache
  end

  test "get_id returns existing model id" do
    id = @manager.get_id("LIVE DAM STADIUM", "DAM")
    assert_equal @existing_model.id, id
  end

  test "get_id returns nil for non-existent model" do
    id = @manager.get_id("Non-existent Model", "DAM")
    assert_nil id
  end

  test "get_id without karaoke_type finds by name only" do
    id = @manager.get_id("LIVE DAM STADIUM")
    assert_equal @existing_model.id, id
  end

  test "get_ids returns array of existing model ids" do
    another_model = KaraokeDeliveryModel.create!(
      name: "LIVE DAM Ai",
      karaoke_type: "DAM",
      order: 2
    )

    ids = @manager.get_ids(["LIVE DAM STADIUM", "LIVE DAM Ai"], "DAM")
    assert_equal 2, ids.size
    assert_includes ids, @existing_model.id
    assert_includes ids, another_model.id
  end

  test "get_ids filters out non-existent models" do
    ids = @manager.get_ids(["LIVE DAM STADIUM", "Non-existent"], "DAM")
    assert_equal 1, ids.size
    assert_equal @existing_model.id, ids.first
  end

  test "find_or_create_id returns existing model id" do
    id = @manager.find_or_create_id("LIVE DAM STADIUM", "DAM")
    assert_equal @existing_model.id, id

    # モデルが増えていないことを確認
    assert_equal 1, KaraokeDeliveryModel.count
  end

  test "find_or_create_id creates new model when not found" do
    assert_difference 'KaraokeDeliveryModel.count', 1 do
      id = @manager.find_or_create_id("New Model", "JOYSOUND")
      assert_not_nil id

      new_model = KaraokeDeliveryModel.find(id)
      assert_equal "New Model", new_model.name
      assert_equal "JOYSOUND", new_model.karaoke_type
    end
  end

  test "find_or_create_ids handles mixed existing and new models" do
    assert_difference 'KaraokeDeliveryModel.count', 2 do
      ids = @manager.find_or_create_ids(
        ["LIVE DAM STADIUM", "New Model 1", "New Model 2"],
        "DAM"
      )
      assert_equal 3, ids.size
      assert_includes ids, @existing_model.id
    end
  end

  test "cache is refreshed after TTL expires" do
    # 最初のアクセスでキャッシュを作成
    @manager.get_id("LIVE DAM STADIUM", "DAM")

    # 新しいモデルを直接データベースに追加
    new_model = KaraokeDeliveryModel.create!(
      name: "Direct DB Model",
      karaoke_type: "DAM",
      order: 3
    )

    # TTLが切れる前はキャッシュから取得できない
    assert_nil @manager.get_id("Direct DB Model", "DAM")

    # TTLを過ぎた時間に設定してキャッシュをリフレッシュ
    travel DeliveryModelManager::CACHE_TTL.minutes + 1.second do
      id = @manager.get_id("Direct DB Model", "DAM")
      assert_equal new_model.id, id
    end
  end

  test "thread safety of find_or_create_id" do
    threads = []
    ids = []
    mutex = Mutex.new

    # 複数スレッドから同じモデルを作成しようとする
    10.times do
      threads << Thread.new do
        id = @manager.find_or_create_id("Concurrent Model", "DAM")
        mutex.synchronize { ids << id }
      end
    end

    threads.each(&:join)

    # すべて同じIDが返されることを確認
    assert_equal 10, ids.size
    assert_equal 1, ids.uniq.size

    # データベースには1つしか作成されていないことを確認
    assert_equal 1, KaraokeDeliveryModel.where(name: "Concurrent Model", karaoke_type: "DAM").count
  end

  test "refresh_cache updates cache immediately" do
    # 新しいモデルを直接データベースに追加
    new_model = KaraokeDeliveryModel.create!(
      name: "Refresh Test Model",
      karaoke_type: "JOYSOUND",
      order: 4
    )

    # リフレッシュ前はキャッシュにない
    assert_nil @manager.get_id("Refresh Test Model", "JOYSOUND")

    # 手動でキャッシュをリフレッシュ
    @manager.refresh_cache

    # リフレッシュ後は取得できる
    id = @manager.get_id("Refresh Test Model", "JOYSOUND")
    assert_equal new_model.id, id
  end

  test "clear_cache removes all cached data" do
    # キャッシュを作成
    @manager.get_id("LIVE DAM STADIUM", "DAM")

    # キャッシュをクリア
    @manager.clear_cache

    # 次のアクセスでキャッシュが再作成される
    id = @manager.get_id("LIVE DAM STADIUM", "DAM")
    assert_equal @existing_model.id, id
  end
end
