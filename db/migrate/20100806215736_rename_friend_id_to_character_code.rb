class RenameFriendIdToCharacterCode < ActiveRecord::Migration
  def self.up
	rename_column :characters, :friend_id, :character_code
  end

  def self.down
	rename_column :characters, :friend_id, :charater_code
  end
end
