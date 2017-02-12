class CreateAchievementDatas < ActiveRecord::Migration
  def self.up
    create_table :achievements do |t|
      t.string :name
      t.text :description
	  t.integer :achievement_id
	  t.integer :bnet_id
	  t.integer :icon_id
      t.integer :icon_row
      t.integer :icon_column
      t.integer :category_id
	  t.integer :finished_at, :default => 0, :null => 0
	  t.integer :points, :default => 0, :null => 0
	  t.integer :series_id
	  t.boolean :is_parent, :default => false, :null => false
	  t.boolean :is_meta, :default => false, :null => false
    end
	
	add_index :achievements, :category_id
	add_index :achievements, :achievement_id
  end

  def self.down
    drop_table :achievements
  end
end
