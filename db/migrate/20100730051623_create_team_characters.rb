class CreateTeamCharacters < ActiveRecord::Migration
  def self.up
    create_table :team_characters do |t|
      t.integer :team_id
      t.integer :character_id
    end
	add_index :team_characters, :team_id
	add_index :team_characters, :character_id
  end

  def self.down
    drop_table :team_characters
  end
end
