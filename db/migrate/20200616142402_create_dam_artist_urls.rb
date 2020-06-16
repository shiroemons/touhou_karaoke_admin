class CreateDamArtistUrls < ActiveRecord::Migration[6.0]
  def change
    create_table :dam_artist_urls, id: :uuid do |t|
      t.string :url, null: false

      t.timestamps
    end
  end
end
