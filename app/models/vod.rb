class Vod < ActiveRecord::Base
	has_one :player_one_char, :foreign_key => :id, :primary_key => :player_one_id, :class_name => "Character"
	has_one :player_two_char, :foreign_key => :id, :primary_key => :player_two_id, :class_name => "Character"
	has_one :site, :foreign_key => :id, :primary_key => :vod_site_id, :class_name => "VodSite"
end