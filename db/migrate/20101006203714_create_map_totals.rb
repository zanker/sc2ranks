class CreateMapTotals < ActiveRecord::Migration
  def self.up
    create_table :map_totals do |t|
      t.datetime :stat_date
      t.integer :total_games
      t.integer :map_id
    end

	add_index :map_totals, :map_id
	add_index :map_totals, :stat_date
  end

  def self.down
    drop_table :map_totals
  end
end
