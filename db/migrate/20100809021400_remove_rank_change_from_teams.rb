class RemoveRankChangeFromTeams < ActiveRecord::Migration
  def self.up
	remove_column :teams, :rank_change
  end

  def self.down
  end
end
