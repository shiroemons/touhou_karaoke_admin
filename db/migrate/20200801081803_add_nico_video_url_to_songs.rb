class AddNicoVideoUrlToSongs < ActiveRecord::Migration[6.0]
  def change
    add_column :songs, :nicovideo_url, :string, null: false, default: ""
  end
end
