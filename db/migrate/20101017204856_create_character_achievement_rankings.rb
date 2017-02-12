class CreateCharacterAchievementRankings < ActiveRecord::Migration
  def self.up
    create_table :character_achievement_rankings do |t|
		t.integer :character_id
		t.integer :points, :default => 0
		t.integer :world_rank, :default => 0
		t.integer :region_rank, :default => 0
    end

	add_index :character_achievement_rankings, :character_id
	add_index :character_achievement_rankings, :points
  end

  def self.down
    drop_table :character_achievement_rankings
  end
end
