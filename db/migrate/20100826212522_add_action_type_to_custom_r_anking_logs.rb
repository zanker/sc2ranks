class AddActionTypeToCustomRAnkingLogs < ActiveRecord::Migration
  def self.up
    add_column :custom_ranking_logs, :action_type, :integer
  end

  def self.down
    remove_column :custom_ranking_logs, :action_type
  end
end
