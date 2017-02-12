class CreateCharacterReplays < ActiveRecord::Migration
  def self.up
    create_table :replay_characters do |t|
      t.integer :character_id
      t.integer :replay_id
      t.integer :played_race
	  t.integer :team_id
    end

	add_index :replay_characters, :character_id
	add_index :replay_characters, :replay_id
  end

  def self.down
    drop_table :replay_characters
  end
end
