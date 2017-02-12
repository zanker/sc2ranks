class AddHashIdtoReplays < ActiveRecord::Migration
  def self.up
    add_column :replays, :hash_id, :string
  end

  def self.down
    remove_column :replays, :hash_id
  end
end
