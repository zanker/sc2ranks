class CreateReplays < ActiveRecord::Migration
  def self.up
    create_table :replays do |t|
      t.string :bracket
      t.integer :map_id
      t.string :site_url
      t.datetime :played_on
      t.string :game_version
      t.integer :match_length
    end

	add_index :replays, :map_id
	add_index :replays, :bracket
  end

  def self.down
    drop_table :replays
  end
end
