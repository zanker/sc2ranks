class CreateDivisions < ActiveRecord::Migration
  def self.up
    create_table :divisions do |t|
      t.string :region
      t.string :name
      t.integer :league
	  t.integer :bracket
	  t.integer :bnet_id
	  t.integer :total_teams
	  t.integer :min_points
	  t.integer :max_points
	  t.integer :point_average
	  t.integer :games_average
	  t.float :win_average
	  t.datetime :updated_at
    end

	add_index :divisions, :region
	add_index :divisions, :league
	add_index :divisions, :bracket
  end

  def self.down
    drop_table :divisions
  end
end
