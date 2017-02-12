class AddRaceCompToTeams < ActiveRecord::Migration
  def self.up
    add_column :teams, :race_comp, :string
	add_index :teams, :race_comp
  end

  def self.down
    remove_column :teams, :race_comp
  end
end
