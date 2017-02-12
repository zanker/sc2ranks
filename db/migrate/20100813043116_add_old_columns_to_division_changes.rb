class AddOldColumnsToDivisionChanges < ActiveRecord::Migration
  def self.up
    add_column :division_changes, :old_wins, :integer
    add_column :division_changes, :old_losses, :integer
    add_column :division_changes, :old_points, :integer
  end

  def self.down
    remove_column :division_changes, :old_points
    remove_column :division_changes, :old_losses
    remove_column :division_changes, :old_wins
  end
end
