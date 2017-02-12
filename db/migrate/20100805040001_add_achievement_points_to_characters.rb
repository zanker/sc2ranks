class AddAchievementPointsToCharacters < ActiveRecord::Migration
  def self.up
    add_column :characters, :achievement_points, :integer
  end

  def self.down
    remove_column :characters, :achievement_points
  end
end
