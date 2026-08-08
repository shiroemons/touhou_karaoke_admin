class AddUniqueIndexToCirclesName < ActiveRecord::Migration[8.1]
  INDEX_NAME = 'index_circles_on_name'.freeze

  def up
    raise_if_duplicate_names_exist!
    add_index :circles, :name, unique: true, name: INDEX_NAME, if_not_exists: true
  end

  def down
    remove_index :circles, name: INDEX_NAME, if_exists: true
  end

  private

  def raise_if_duplicate_names_exist!
    duplicate = connection.select_one(<<~SQL.squish)
      SELECT name, COUNT(*) AS duplicate_count
      FROM #{connection.quote_table_name(:circles)}
      GROUP BY name
      HAVING COUNT(*) > 1
      LIMIT 1
    SQL
    return if duplicate.blank?

    raise ActiveRecord::IrreversibleMigration,
          "circles has duplicate name=#{duplicate.fetch('name').inspect} (duplicate_count=#{duplicate.fetch('duplicate_count')}). Run make data-duplicate-report and clean data before adding the unique index."
  end
end
