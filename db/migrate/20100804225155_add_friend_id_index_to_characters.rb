class AddFriendIdIndexToCharacters < ActiveRecord::Migration
  def self.up
	add_index :characters, :friend_id
  end

  def self.down
	remove_index :characters, :friend_id
  end
end
