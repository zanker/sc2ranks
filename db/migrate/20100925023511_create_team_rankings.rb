class CreateTeamRankings < ActiveRecord::Migration
  def self.up
    create_table :team_rankings do |t|
      t.integer :team_id
      t.integer :world_rank
      t.integer :region_rank
    end

	add_index :team_rankings, :team_id
  end

  def self.down
    drop_table :team_rankings
  end
end
