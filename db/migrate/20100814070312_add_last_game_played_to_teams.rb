class AddLastGamePlayedToTeams < ActiveRecord::Migration
  def self.up
    add_column :teams, :last_game_at, :datetime
	remove_index :teams, :updated_at
	add_index :teams, :last_game_at
  end

  def self.down
	remove_index :teams, :last_game_at
    remove_column :teams, :last_game_at
	add_index :teams, :updated_at
  end
end