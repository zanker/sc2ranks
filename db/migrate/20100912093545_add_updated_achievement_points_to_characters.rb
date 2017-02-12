class AddUpdatedAchievementPointsToCharacters < ActiveRecord::Migration
  def self.up
    add_column :characters, :updated_achievements, :integer
  end

  def self.down
    remove_column :characters, :updated_achievements
  end
end
