class AddWinsAndLossesAndWinRatioToTeamHistory < ActiveRecord::Migration
  def self.up
    add_column :team_histories, :wins, :integer
    add_column :team_histories, :losses, :integer
	add_column :team_histories, :win_ratio, :float
  end

  def self.down
    remove_column :team_histories, :losses
    remove_column :team_histories, :wins
	remove_column :team_histories, :win_ratio
  end
end
