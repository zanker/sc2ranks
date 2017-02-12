class AddTotalGamesToMaps < ActiveRecord::Migration
  def self.up
    add_column :maps, :total_games, :integer
  end

  def self.down
    remove_column :maps, :total_games
  end
end
