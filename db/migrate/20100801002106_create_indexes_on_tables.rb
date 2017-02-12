class CreateIndexesOnTables < ActiveRecord::Migration
  def self.up
	add_index :teams, :points
	add_index :teams, :division_id
  end

  def self.down
	remove_index :teams, :points
	remove_index :division_id
  end
end
