class CreateCircles < ActiveRecord::Migration[6.0]
  def change
    create_table :circles, id: :uuid do |t|
      t.string :name, null: false

      t.timestamps
    end
  end
end
