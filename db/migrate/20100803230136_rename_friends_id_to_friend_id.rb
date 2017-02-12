class RenameFriendsIdToFriendId < ActiveRecord::Migration
  def self.up
	rename_column :characters, :friends_id, :friend_id
  end

  def self.down
	rename_column :characters, :friend_id, :friends_id
  end
end
