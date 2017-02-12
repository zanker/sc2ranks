class Replay < ActiveRecord::Base
	has_many :replay_characters
	has_many :characters, :through => :replay_characters
	has_one :map, :foreign_key => :id, :primary_key => :map_id
	has_one :site, :class_name => "ReplaySite", :foreign_key => :id, :primary_key => :replay_site_id
end
