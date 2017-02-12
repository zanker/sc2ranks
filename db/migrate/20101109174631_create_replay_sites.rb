class CreateReplaySites < ActiveRecord::Migration
  def self.up
    create_table :replay_sites do |t|
      t.string :name
	  t.string :url
      t.datetime :updated_at
    end

	add_index :replay_sites, :url
	
	ReplaySite.create(:name => "ReplayFu", :url => "replayfu.com")
	ReplaySite.create(:name => "SC2Replayed", :url => "sc2replayed.com")
  end

  def self.down
    drop_table :replay_sites
  end
end
