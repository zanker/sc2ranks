class Map < ActiveRecord::Base
	has_many :matches, :class_name => "MatchHistory", :foreign_key => :map_id
	has_many :stats, :class_name => "MatchTotal", :foreign_key => :map_id
	has_one :overall_stat, :class_name => "MatchTotal", :foreign_key => :map_id, :conditions => "stat_date IS NULL"
end
