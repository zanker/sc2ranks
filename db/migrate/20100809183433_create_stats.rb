class CreateStats < ActiveRecord::Migration
  def self.up
    create_table :stats do |t|
      t.string :region
	  t.integer :bracket
	  t.integer :race
      t.integer :league
      t.decimal :stat_percent
      t.integer :stat_number
      t.integer :stat_type
	  t.integer :player_group
      t.datetime :created_at
    end

	add_index :stats, :region
	add_index :stats, :stat_type
	add_index :stats, :player_group
  end

  def self.down
    drop_table :stats
  end
end
