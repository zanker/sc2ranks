class CreateArmoryJobs < ActiveRecord::Migration
  def self.up
	  create_table :armory_jobs do |t|
	    t.string :region
	    t.string :class_name
	    t.integer :priority
	    t.text :yaml_args
		t.integer :bnet_id
		t.integer :bracket
	    t.integer :retries, :default => 0
	    t.string :locked_by
	    t.datetime :locked_at
	    t.datetime :created_at
	  end

	  add_index :armory_jobs, :class_name
	  add_index :armory_jobs, :created_at
	  add_index :armory_jobs, :locked_at
	  add_index :armory_jobs, :locked_by
	  add_index :armory_jobs, :priority
  end

  def self.down
	drop_table :armory_jobs
  end
end
