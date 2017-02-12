class CreateCharacters < ActiveRecord::Migration
  def self.up
    create_table :characters do |t|
      t.string :region
      t.string :name
	  t.integer :fav_race
	  t.integer :bnet_id
	  t.integer :friends_id
	  t.integer :total_teams
	  t.datetime :updated_at
    end

	add_index :characters, :region
	add_index :characters, :bnet_id
  end

  def self.down
    drop_table :characters
  end
end
