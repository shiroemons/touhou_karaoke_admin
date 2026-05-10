require 'test_helper'

module Admin
  class OperationRunnerTest < ActiveSupport::TestCase
    test 'exports selected songs only' do
      artist = create_display_artist(name: 'Export Artist')
      selected = create_song(display_artist: artist, title: 'Selected Export Song')
      excluded = create_song(display_artist: artist, title: 'Excluded Export Song')
      original_song = create_original_song(title: 'Export Original')
      selected.original_songs << original_song
      resource = ResourceRegistry.fetch(:song)
      operation = resource.operations.find { |item| item.key == 'export_songs' }

      result = OperationRunner.new(
        resource:,
        operation:,
        record: nil,
        params: { selected_ids: [selected.id], operation_progress_id: SecureRandom.uuid },
        scope: Song.where(id: [selected.id, excluded.id])
      ).run

      assert_equal 'songs.tsvを生成しました。', result.message
      assert_equal 'songs.tsv', result.download_filename
      assert_includes result.download_data, selected.title
      assert_includes result.download_data, original_song.title
      assert_not_includes result.download_data, excluded.title
    end

    test 'requires selection when operation demands selected ids' do
      resource = ResourceRegistry.fetch(:song)
      operation = resource.operations.find { |item| item.key == 'export_songs' }
      progress_id = SecureRandom.uuid
      runner = OperationRunner.new(resource:, operation:, record: nil, params: { selected_ids: [], operation_progress_id: progress_id }, scope: Song.all)

      assert_raises(ArgumentError) { runner.run }
      assert_equal 'failed', OperationProgress.read(progress_id)[:state]
      assert_equal '対象を選択してください。', OperationProgress.read(progress_id)[:detail]
    end

    test 'runs member method operations on the record' do
      first = create_delivery_model(name: 'First', order: 1)
      second = create_delivery_model(name: 'Second', order: 2)
      resource = ResourceRegistry.fetch(:karaoke_delivery_model)
      operation = resource.operations.find { |item| item.key == 'move_higher' }

      result = OperationRunner.new(
        resource:,
        operation:,
        record: second,
        params: { operation_progress_id: SecureRandom.uuid },
        scope: KaraokeDeliveryModel.all
      ).run

      assert_equal '上へ移動を実行しました。', result.message
      assert_operator second.reload.order, :<, first.reload.order
    end

    test 'imports tsv rows and skips missing songs or original titles' do
      artist = create_display_artist(name: 'Import Artist')
      song = create_song(display_artist: artist, title: 'Import Song')
      original_song = create_original_song(title: 'Import Original')
      path = Rails.root.join('tmp', "operation_runner_import_#{SecureRandom.hex(8)}.tsv")
      File.write(path, [
        "id\tkaraoke_type\tdisplay_artist_name\ttitle\toriginal_songs\tyoutube_url\tnicovideo_url\tapple_music_url\tyoutube_music_url\tspotify_url\tline_music_url",
        "#{song.id}\tDAM\tImport Artist\tImport Song\t#{original_song.title}\thttps://youtube.example/import\t\t\t\t\t",
        "#{SecureRandom.uuid}\tDAM\tMissing\tMissing\t#{original_song.title}\t\t\t\t\t\t",
        "#{song.id}\tDAM\tImport Song\tImport Song\t\t\t\t\t\t"
      ].join("\n"))
      upload = Rack::Test::UploadedFile.new(path, 'text/tab-separated-values')
      resource = ResourceRegistry.fetch(:song)
      operation = resource.operations.find { |item| item.key == 'import_songs_with_original_songs' }

      result = OperationRunner.new(
        resource:,
        operation:,
        record: nil,
        params: { operation_fields: { tsv_file: upload }, operation_progress_id: SecureRandom.uuid },
        scope: Song.all
      ).run

      assert_equal 'インポートが完了しました。更新件数: 1件、スキップ件数: 2件', result.message
      assert_equal [original_song], song.reload.original_songs.to_a
      assert_equal 'https://youtube.example/import', song.youtube_url
    ensure
      File.delete(path) if path && File.exist?(path)
    end

    test 'rejects non tsv import uploads' do
      path = Rails.root.join('tmp', "operation_runner_import_#{SecureRandom.hex(8)}.txt")
      File.write(path, 'not tsv')
      upload = Rack::Test::UploadedFile.new(path, 'application/octet-stream')
      resource = ResourceRegistry.fetch(:song)
      operation = resource.operations.find { |item| item.key == 'import_songs_with_original_songs' }
      runner = OperationRunner.new(
        resource:,
        operation:,
        record: nil,
        params: { operation_fields: { tsv_file: upload }, operation_progress_id: SecureRandom.uuid },
        scope: Song.all
      )

      assert_raises(ArgumentError) { runner.run }
    ensure
      File.delete(path) if path && File.exist?(path)
    end
  end
end
