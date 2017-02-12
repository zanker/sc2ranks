class CreateMatchTotal < ActiveRecord::Migration
  def self.up
	if table_exists?(:map_totals)
		drop_table :map_totals
	end
	
    create_table :match_totals do |t|
      t.datetime :stat_date
      t.integer :total_games, :default => 0
      t.integer :map_id
    end

	add_index :match_totals, :map_id
	add_index :match_totals, :stat_date
  end

  def self.down
    drop_table :match_totals
  end
end
