class RemoveFavRAceFromCharacters < ActiveRecord::Migration
  def self.up
	remove_column :characters, :fav_race
  end

  def self.down
  end
end
