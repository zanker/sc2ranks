class AddWorldRanktoTeamHistories < ActiveRecord::Migration
  def self.up
	add_column :team_histories, :world_rank, :integer
  end

  def self.down
	remove_column :team_histories, :world_rank
  end
end
