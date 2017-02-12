class CreateTeamHistories < ActiveRecord::Migration
  def self.up
    create_table :team_histories do |t|
	  t.integer :team_id
      t.integer :points
      t.integer :league
    end
	
	add_index :team_histories, :team_id
  end

  def self.down
    drop_table :team_histories
  end
end
