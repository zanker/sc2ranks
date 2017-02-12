class CreateCharacterAchievements < ActiveRecord::Migration
  def self.up
    create_table :character_achievements do |t|
      t.integer :achievement_id
      t.integer :character_id
	  t.decimal :progress
	  t.datetime :earned_on
	  t.boolean :is_recent
    end
	
	add_index :character_achievements, :achievement_id
	add_index :character_achievements, :character_id
  end

  def self.down
    drop_table :character_achievements
  end
end
