class AddBuildVersionToReplays < ActiveRecord::Migration
  def self.up
    add_column :replays, :build_version, :integer
  end

  def self.down
    remove_column :replays, :build_version
  end
end
