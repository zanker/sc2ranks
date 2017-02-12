class AddLastGameToMaps < ActiveRecord::Migration
  def self.up
    add_column :maps, :last_game, :datetime
  end

  def self.down
    remove_column :maps, :last_game
  end
end
