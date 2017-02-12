class CreateTeamHistoryPeriods < ActiveRecord::Migration
  def self.up
    create_table :team_history_periods do |t|
      t.integer :starts_at
      t.integer :ends_at
      t.datetime :created_at
    end

	add_index :team_history_periods, :created_at
  end

  def self.down
    drop_table :team_history_periods
  end
end
