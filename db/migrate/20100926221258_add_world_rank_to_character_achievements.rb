class AddWorldRankToCharacterAchievements < ActiveRecord::Migration
  def self.up
    add_column :character_achievements, :cached_world_rank, :integer
  end

  def self.down
    remove_column :character_achievements, :cached_world_rank
  end
end
