class AddUpdatedAtToTeams < ActiveRecord::Migration
  def self.up
	add_index :teams, :updated_at
	remove_column :characters, :is_verified
  end

  def self.down
	remove_index :teams, :updated_at
	add_column :characters, :is_verified, :boolean
  end
end
