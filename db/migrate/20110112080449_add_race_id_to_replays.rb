class AddRaceIdToReplays < ActiveRecord::Migration
  def self.up
    add_column :replays, :race_comp, :string
	add_index :replays, :race_comp
	
	rename_column :replay_characters, :team_id, :side_id
	add_column :replay_characters, :team_id, :integer
	add_index :replay_characters, :team_id
  end

  def self.down
    remove_column :replays, :race_id
  end
end
