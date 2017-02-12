class CreateMatchHistories < ActiveRecord::Migration
  def self.up
    create_table :match_histories do |t|
      t.integer :character_id
      t.integer :map_id
      t.integer :bracket
      t.integer :results
      t.integer :points, :default => 0
      t.datetime :played_on
    end

	add_index :match_histories, :character_id
	add_index :match_histories, :map_id
	add_index :match_histories, :bracket
	add_index :match_histories, :played_on
  end

  def self.down
    drop_table :match_histories
  end
end
