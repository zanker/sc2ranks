class TeamCharacter < ActiveRecord::Base
	belongs_to :character
	belongs_to :team
	
	def race_region_rank
		return (Rails.cache.fetch("race/region/#{self.id}/#{self.fav_race}/#{self.team.points}", :raw => true, :expires_in => 12.hours) do
			return self.live_race_region_rank
		end).to_i
	end

	def live_race_region_rank
		if self.team.is_random || self.team.bracket == 1
			played_race = self.played_race.to_s
			race_cond = "="
		else
			played_race = "%#{self.played_race}%"
			race_cond = "LIKE"
		end
		
		return Team.count(:all, :conditions => ["region = ? AND bracket = ? AND league = ? AND is_random = ? AND points >= ? AND race_comp #{race_cond} ?", self.team.region, self.team.bracket, self.team.league, self.team.is_random, self.team.points, played_race])
	end	

	def played_race
		return self.fav_race || -1
	end
end
