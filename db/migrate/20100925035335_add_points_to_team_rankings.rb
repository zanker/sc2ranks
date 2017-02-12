class AddPointsToTeamRankings < ActiveRecord::Migration
  def self.up
    add_column :team_rankings, :points, :integer
  end

  def self.down
    remove_column :team_rankings, :points
  end
end
