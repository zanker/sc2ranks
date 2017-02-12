class RenamePointAverageToPointsAverageInDivisions < ActiveRecord::Migration
  def self.up
	rename_column :divisions, :point_average, :average_points
	rename_column :divisions, :games_average, :average_games
	rename_column :divisions, :win_average, :average_wins
  end

  def self.down
	rename_column :divisions, :average_points, :point_average
	rename_column :divisions, :average_games, :games_average
	rename_column :divisions, :average_wins, :win_average
  end
end
