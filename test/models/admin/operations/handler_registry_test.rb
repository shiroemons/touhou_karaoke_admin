require 'test_helper'

module Admin
  module Operations
    class HandlerRegistryTest < ActiveSupport::TestCase
      test 'resolves handlers to operation objects' do
        resource = ResourceRegistry.fetch(:song)
        operation = resource.operations.find { |item| item.key == 'export_songs' }
        registry = HandlerRegistry.new(resource:, operation:, params: {}, scope: Song.all)

        assert_instance_of SongTsvOperation, registry.resolve(:export_songs)
        assert_nil registry.resolve(:unknown_handler)
      end
    end
  end
end
