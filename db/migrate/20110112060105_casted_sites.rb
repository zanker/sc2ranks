class CastedSites < ActiveRecord::Migration
	def self.up
		create_table :vod_sites do |t|
			t.string :name
			t.string :url
			t.datetime :updated_at
		end
		
		add_index :vod_sites, :url
		
		VodSite.create(:name => "SC2Casts", :url => "http://sc2casts.com")
			
		create_table :vods do |t|
			t.integer :vod_site_id
				
			t.integer :series_id
			t.string :series_url
			t.string :event
			t.string :event_url
			t.string :url
			t.string :round
			t.string :best_of
			t.integer :best_of_type

			t.string :caster
			t.string :caster_url
			
			t.string :player_one
			t.integer :player_one_id
			t.integer :player_one_race
			
			t.string :player_two
			t.integer :player_two_id
			t.integer :player_two_race
		end
		
		add_index :vods, :series_id
		add_index :vods, :event
		add_index :vods, :player_one_id
		add_index :vods, :player_two_id
		
		add_column :characters, :flag, :integer
	end

	def self.down
		remove_column :characters, :flag
		drop_table :vod_sites
		drop_table :vods
	end
end
