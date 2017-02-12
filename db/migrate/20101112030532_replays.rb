class Replays < ActiveRecord::Migration
  def self.up
	add_column :replays, :replay_site_id, :integer
  end

  def self.down
  end
end
