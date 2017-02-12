class MatchHistory < ActiveRecord::Base
	has_one :map, :foreign_key => :id, :primary_key => :map_id
	has_one :character, :foreign_key => :id, :primary_key => :character_id
	
	def self.translate_date(date)
		units = date.split("/")
		return Time.utc(units[2].to_i, units[0].to_i, units[1].to_i)
	end
end
