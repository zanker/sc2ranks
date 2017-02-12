class CreatePortraitDatas < ActiveRecord::Migration
  def self.up
    create_table :portraits do |t|
      t.string :name
	  t.integer :portrait_id
      t.integer :achievement_id
      t.integer :icon_id
      t.integer :icon_row
      t.integer :icon_column
    end

	add_index :portraits, :achievement_id
	add_index :portraits, :portrait_id
  end

  def self.down
    drop_table :portraits
  end
end
