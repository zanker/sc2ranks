class CreateMaps < ActiveRecord::Migration
  def self.up
    create_table :maps do |t|
	  t.string :region
      t.string :name
	  t.string :name_id
      t.boolean :is_blizzard
      t.string :author
      t.string :mapster_slug
    end
  end

  def self.down
    drop_table :maps
  end
end
