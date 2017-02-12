class CharacterAchievement < ActiveRecord::Base
	has_one :data, :class_name => "Achievement", :foreign_key => :achievement_id, :primary_key => :achievement_id
	
	def world_rank
		#return self.cached_world_rank || (Rails.cache.fetch("/achieve/rank/#{self.earned_on.to_i}/#{self.achievement_id}", :raw => true, :expires_in => 6.hours) do
		#	CharacterAchievement.count(:conditions => ["achievement_id = ? AND earned_on <= ?", self.achievement_id, self.earned_on])
		#end).to_i
		return self.cached_world_rank
	end
		
	# Blizzard gives m/d/yyyy, Ruby expects d.m.yyy before it will parse date
	def self.translate_date(date, region=nil)
		units = date.split("/")
		if region == "us" or region == "la" or region == "sea" or region == "tw"
			return Time.utc(units[2].to_i, units[0].to_i, units[1].to_i)
		elsif region == "kr" or region == "cn"
			return Time.utc(units[0].to_i, units[1].to_i, units[2].to_i)
		else
			return Time.utc(units[2].to_i, units[1].to_i, units[0].to_i)
		end
	end
end
