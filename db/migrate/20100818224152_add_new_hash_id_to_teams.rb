class AddNewHashIdToTeams < ActiveRecord::Migration
  def self.up
    add_column :teams, :new_hash_id, :string
  end

  def self.down
    remove_column :teams, :new_hash_id
  end
end
