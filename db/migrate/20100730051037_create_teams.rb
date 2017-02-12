class CreateTeams < ActiveRecord::Migration
  def self.up
    create_table :teams do |t|
      t.string :region
      t.string :hash_id
      t.integer :points
      t.integer :wins
      t.integer :losses
      t.float :win_ratio
      t.integer :division_rank
      t.integer :division_id
	  t.integer :league
	  t.integer :bracket
	  t.integer :rank_change
	  t.datetime :joined_league
	  t.datetime :updated_at
    end

	add_index :teams, :region
	add_index :teams, :hash_id
	add_index :teams, :league
	add_index :teams, :bracket
  end

  def self.down
    drop_table :teams
  end
end
