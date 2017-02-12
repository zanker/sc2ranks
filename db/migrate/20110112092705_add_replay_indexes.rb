class AddReplayIndexes < ActiveRecord::Migration
  def self.up
	add_index :replays, :build_version
  end

  def self.down
  end
end
