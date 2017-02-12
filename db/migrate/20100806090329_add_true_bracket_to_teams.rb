class AddTrueBracketToTeams < ActiveRecord::Migration
  def self.up
    add_column :teams, :is_random, :boolean
	add_index :teams, :is_random
  end

  def self.down
    remove_column :teams, :is_random
  end
end
