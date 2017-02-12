class CreateDivisionChanges < ActiveRecord::Migration
  def self.up
    create_table :division_changes do |t|
      t.integer :team_id
      t.integer :wins
      t.integer :losses
      t.integer :points
      t.integer :new_league
      t.integer :old_league
    end
  end

  def self.down
    drop_table :division_changes
  end
end
