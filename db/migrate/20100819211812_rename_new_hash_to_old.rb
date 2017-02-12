class RenameNewHashToOld < ActiveRecord::Migration
  def self.up
	rename_column :teams, :hash_id, :old_hash_id
	rename_column :teams, :new_hash_id, :hash_id
  end

  def self.down
  end
end
