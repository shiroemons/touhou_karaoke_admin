require 'test_helper'

module Admin
  class ResourceRegistryTest < ActiveSupport::TestCase
    test 'fetches every configured resource by key' do
      expected_keys = %i[
        original original_song karaoke_delivery_model circle song display_artist
        dam_song dam_artist_url joysound_song joysound_music_post
        song_with_dam_ouchikaraoke song_with_joysound_utasuki
      ]

      assert_equal expected_keys, ResourceRegistry.all.keys
      expected_keys.each do |key|
        assert_equal key, ResourceRegistry.fetch(key).key
      end
    end

    test 'derives route controller and parameter names from resource key' do
      resource = ResourceRegistry.fetch(:karaoke_delivery_model)

      assert_equal 'karaoke_delivery_models', resource.controller_name
      assert_equal 'karaoke_delivery_models', resource.route_name
      assert_equal :karaoke_delivery_model, resource.param_key
    end

    test 'partitions fields by index show and editable form visibility' do
      resource = ResourceRegistry.fetch(:song)

      assert resource.index_fields.all?(&:index)
      assert resource.show_fields.all?(&:show)
      assert(resource.form_fields.all? { |field| field.form && !field.readonly })
      assert_not_includes resource.form_fields.map(&:name), :title
    end

    test 'finds filters by string or symbol name' do
      resource = ResourceRegistry.fetch(:song)

      assert_equal resource.filter_by_name(:karaoke_type), resource.filter_by_name('karaoke_type')
      assert_nil resource.filter_by_name(:missing)
    end

    test 'groups navigable resources without duplicates' do
      grouped_resources = ResourceRegistry.navigation_groups.flat_map(&:second)

      assert_equal ResourceRegistry.navigable.sort_by(&:key), grouped_resources.sort_by(&:key)
      assert_equal grouped_resources.map(&:key).uniq, grouped_resources.map(&:key)
    end

    test 'configured resources expose required attributes' do
      ResourceRegistry.all.each do |key, resource|
        assert_equal key, resource.key
        assert resource.model < ApplicationRecord, "#{key} must reference an application model"
        assert_predicate resource.label, :present?, "#{key} must define a label"
        assert_includes [String, Symbol, Proc], resource.title.class, "#{key} must define a display title"
        assert_predicate resource.fields, :present?, "#{key} must define fields"
      end
    end

    test 'configured resource fields filters and operations have unique keys' do
      ResourceRegistry.all.each_value do |resource|
        assert_unique_names(resource.fields, "#{resource.key} fields")
        assert_unique_names(resource.filters, "#{resource.key} filters")
        assert_unique_names(resource.operations, "#{resource.key} operations", attribute: :key)
        assert_unique_names(resource.operations, "#{resource.key} operation action keys", attribute: :action_key)
      end
    end

    test 'configured operations expose labels groups descriptions and executable targets' do
      ResourceRegistry.all.each_value do |resource|
        resource.operations.each do |operation|
          assert_predicate operation.label, :present?, "#{resource.key}.#{operation.key} must define a label"
          assert_predicate operation.group, :present?, "#{resource.key}.#{operation.key} must define a group"
          assert_predicate operation.description, :present?, "#{resource.key}.#{operation.key} must define a description"

          target_count = [operation.handler, operation.method_name].count(&:present?)
          assert_equal 1, target_count, "#{resource.key}.#{operation.key} must define exactly one handler or method_name"
        end
      end
    end

    test 'configured includes and associations reference model associations' do
      ResourceRegistry.all.each_value do |resource|
        association_names = resource.model.reflect_on_all_associations.map(&:name)

        assert_valid_includes(resource.model, resource.includes, resource.key)

        resource.associations.each do |association|
          assert_includes association_names, association, "#{resource.key} association #{association} must reference an association"
        end
      end
    end

    test 'configured search columns resolve to model or association columns' do
      ResourceRegistry.all.each_value do |resource|
        resource.search.each_key do |key|
          column_path = key.to_s.delete_suffix('_cont')
          next if column_path == 'm'

          assert_search_column_exists(resource, column_path)
        end
      end
    end

    test 'strong parameters are backed by editable form fields' do
      ResourceRegistry.all.each_value do |resource|
        permitted_field_names = resource.form_fields.map { |field| field.name.to_sym } + association_id_parameter_names(resource)
        flattened_parameters = flatten_parameter_keys(resource.strong_parameters)

        assert(flattened_parameters.all? { |name| permitted_field_names.include?(name) }, "#{resource.key} has strong parameters not present in editable fields or associations")
      end
    end

    test 'async operations do not require direct file uploads' do
      ResourceRegistry.all.each_value do |resource|
        resource.operations.select(&:async).each do |operation|
          assert(operation.inputs.none? { |input| input[:type] == :file }, "#{resource.key}.#{operation.key} cannot be async with file inputs")
        end
      end
    end

    test 'repeatable operations are async and bounded' do
      ResourceRegistry.all.each_value do |resource|
        resource.operations.select(&:repeat_while_created).each do |operation|
          assert_predicate operation, :async, "#{resource.key}.#{operation.key} must run async when repeatable"
          assert_operator operation.max_attempts, :>, 1, "#{resource.key}.#{operation.key} must allow multiple attempts"
        end
      end
    end

    test 'workflow steps reference configured operations' do
      WorkflowDefinition.all.each_value do |workflow|
        workflow.stages.each do |stage|
          stage.branches.each do |branch|
            branch.steps.each do |step|
              resource = ResourceRegistry.fetch(step.resource_key)

              assert(resource.operations.any? { |operation| operation.key == step.operation_key }, "#{workflow.key} #{step.resource_key}.#{step.operation_key} must reference a configured operation")
            end
          end
        end
      end
    end

    test 'collection and member operations expose stable keys and action keys' do
      song = ResourceRegistry.fetch(:song)
      export = song.operations.find { |operation| operation.key == 'export_songs' }
      dam_song = ResourceRegistry.fetch(:dam_song)
      fetch = dam_song.operations.find { |operation| operation.key == 'fetch_dam_song' }

      assert_equal 'ExportSongs', export.action_key
      assert_equal :collection, export.scope
      assert_equal :required, export.selection
      assert_equal 'FetchDamSong', fetch.action_key
      assert_equal :fetch_dam_song, fetch.handler
      assert(fetch.inputs.any? { |input| input[:name] == :dam_song_url })
    end

    private

    def assert_unique_names(items, label, attribute: :name)
      values = items.map { |item| item.public_send(attribute).to_s }

      assert_equal values.uniq, values, "#{label} must be unique"
    end

    def assert_search_column_exists(resource, column_path)
      return assert_includes(resource.model.column_names, column_path) if resource.model.column_names.include?(column_path)

      association = resource.model.reflect_on_all_associations.find { |candidate| column_path.start_with?("#{candidate.name}_") }
      assert association, "#{resource.key} search #{column_path} must reference an association"

      column = column_path.delete_prefix("#{association.name}_")
      assert_includes association.klass.column_names, column, "#{resource.key} search #{column_path} must reference an association column"
    end

    def flatten_parameter_keys(parameters)
      parameters.flat_map do |parameter|
        case parameter
        when Hash
          parameter.keys
        else
          parameter
        end
      end.map(&:to_sym)
    end

    def association_id_parameter_names(resource)
      resource.associations.filter_map do |association|
        reflection = resource.model.reflect_on_association(association)
        :"#{association.to_s.singularize}_ids" if reflection&.collection?
      end
    end

    def assert_valid_includes(model, includes, resource_key)
      Array(includes).each do |item|
        case item
        when Hash
          item.each do |association, nested|
            reflection = assert_valid_include(model, association, resource_key)
            assert_valid_includes(reflection.klass, nested, resource_key)
          end
        else
          assert_valid_include(model, item, resource_key)
        end
      end
    end

    def assert_valid_include(model, association, resource_key)
      reflection = model.reflect_on_association(association)

      assert reflection, "#{resource_key} includes #{model.name}.#{association} must reference an association"
      reflection
    end
  end
end
