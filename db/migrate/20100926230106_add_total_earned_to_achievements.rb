class AddTotalEarnedToAchievements < ActiveRecord::Migration
  def self.up
    add_column :achievements, :world_earned_by, :integer
  end

  def self.down
    remove_column :achievements, :world_earned_by
  end
end
