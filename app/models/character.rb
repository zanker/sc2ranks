class Character < ActiveRecord::Base
	has_many :team_characters
 	has_many :teams, :through => :team_characters, :finder_sql => 'SELECT teams.* FROM teams JOIN team_characters ON team_characters.team_id=team.id WHERE team_characters.character_id = #{id} AND teams.division_id IS NOT NULL'
 	has_many :all_teams, :through => :team_characters, :source => :team
	has_many :achievements, :class_name => "CharacterAchievement", :dependent => :destroy
	has_many :matches, :class_name => "MatchHistory", :dependent => :destroy
	has_many :replay_characters
	has_many :replays, :through => :replay_characters
	has_one :achieve_rankings, :class_name => "CharacterAchievementRanking", :dependent => :destroy
	has_one :portrait, :foreign_key => :portrait_id, :primary_key => :portrait_id
	
	def recache_achievements
		return if self.achieve_rankings && self.achieve_rankings.points == self.achievement_points
		return if (Rails.cache.fetch("block/ranking/achievements", :raw => true, :expires_in => 30.minutes) do
			FileTest.exists?("#{RAILS_ROOT}/tmp/cache-achievements-rankings.lock") ? "1" : "0"
		end) == "1"
		
		self.achieve_rankings ||= CharacterAchievementRanking.new(:character_id => self.id)
		self.achieve_rankings.points = self.achievement_points
		self.achieve_rankings.world_rank = self.live_achieve_world_rank
		self.achieve_rankings.region_rank = self.live_achieve_region_rank
		self.achieve_rankings.save
	end
	
	# World methods for achievements
	def achieve_world_rank
		return 0 if self.achievement_points == 0

		self.recache_achievements
		return (self.achieve_rankings && !self.achieve_rankings.world_rank.nil? ? self.achieve_rankings.world_rank : self.live_achieve_world_rank) || 0
	end
	
	def achieve_world_competition
		return (Rails.cache.fetch("population/chars/global", :raw => true, :expires_in => 6.hours) do
			Character.count
		end).to_i
	end

	def live_achieve_world_rank
		return (Rails.cache.fetch("achieve/rank/#{self.achievement_points}", :raw => true, :expires_in => 6.hours) do
			return Character.count(:conditions => ["achievement_points >= ?", self.achievement_points])
		end).to_i
	end
	
	# Region methods for achievements
	def achieve_region_rank
		return 0 if self.achievement_points == 0
		self.recache_achievements
		return (self.achieve_rankings && !self.achieve_rankings.region_rank.nil? ? self.achieve_rankings.region_rank : self.live_achieve_region_rank) || 0
	end

	def achieve_region_competition
		return (Rails.cache.fetch("population/chars/#{self.region}", :raw => true, :expires_in => 6.hours) do
			Character.count(:conditions => {:region => self.region})
		end).to_i
	end
	
	def live_achieve_region_rank
		return (Rails.cache.fetch("achieve/rank/#{self.region}/#{self.achievement_points}", :raw => true, :expires_in => 6.hours) do
			Character.count(:conditions => ["region = ? AND achievement_points >= ?", self.region, self.achievement_points])
		end).to_i
	end

	def full_name
		if self.tag
			"[#{self.tag}] #{self.name}"
		else
			self.name
		end		
	end

	def self.name_split(name)
		# figure out what we're using
		bnet_id = name.split("!", 2)
		if bnet_id.length > 1
			return "bnet", bnet_id[0], bnet_id[1].to_i
		end
		
		character_code = name.split("$", 2)
		if character_code.length > 1
			return "code", character_code[0], character_code[1].to_i
		end
	end
end
