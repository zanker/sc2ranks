class IsRandomToDivisions < ActiveRecord::Migration
  def self.up
    add_column :divisions, :is_random, :boolean
	add_index :divisions, :is_random
  end

  def self.down
    remove_column :divisions, :is_random
  end
end
