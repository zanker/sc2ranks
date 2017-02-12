class RemoveWasAddedFromCustomRAnkingLogs < ActiveRecord::Migration
  def self.up
	remove_column :custom_ranking_logs, :was_added
  end

  def self.down
  end
end
