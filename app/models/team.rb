class Team < ActiveRecord::Base
	has_many :team_characters
	has_many :characters, :through => :team_characters
	has_one :division, :foreign_key => :id, :primary_key => :division_id
	has_many :histories, :class_name => "TeamHistory"
	has_one :first_character, :through => :team_characters, :source => :character
	has_one :region_pool, :class_name => "RegionBonusPool", :foreign_key => :region, :primary_key => :region
	has_one :rankings, :class_name => "TeamRankings"

	scope "division_id IS NOT NULL"
	
	def has_losses?
		true
		#( self.league && self.league >= LEAGUES["master"] )
	end
	
	# Builds history logs
	def find_history_range()
		history = self.histories.first(:select => "MIN(team_history_periods.created_at) as oldest_time, MAX(team_history_periods.created_at) as newest_time", :joins => "JOIN team_history_periods ON (team_histories.id >= team_history_periods.starts_at AND team_histories.id <= team_history_periods.ends_at)")
		unless history
			return nil
		end
		
		return {:start_at => Time.parse(history.oldest_time), :ends_at => Time.parse(history.newest_time)}
	end
		
	def build_history(start_time=nil)
		cache_time = start_time.nil? && 6.hours || start_time <= 32.days.ago && 24.hours || 1.hour
		return (Rails.cache.fetch("logs/#{self.cache_key}/#{start_time.to_i}", :expires_in => cache_time) do
			points, ranks = [], []
			
			time_filter = start_time && ["team_history_periods.created_at >= ? AND team_history_periods.created_at <= ?", start_time, start_time + 1.month]
			
			last_history = nil
			self.histories.all(:select => "team_history_periods.created_at, team_histories.points, team_histories.league, team_histories.world_rank", :conditions => time_filter, :joins => "JOIN team_history_periods ON (team_histories.id >= team_history_periods.starts_at AND team_histories.id <= team_history_periods.ends_at)", :order => "team_history_periods.created_at ASC").each do |history|
				created_at = Time.parse(history.created_at)
				league = LEAGUE_NAMES[history.league.to_i]
				league = nil if last_history && last_history.league == history.league

				points.push({:x => created_at.to_s(:js), :y => history.points.to_i, :name => league})
				ranks.push([created_at.to_s(:js), (history.world_rank || last_history && last_history.world_rank).to_i])
			
				last_history = history
			end
			
			{:points => points, :ranks => ranks}
		end)
	end
	
	# Smart rankings, for 1v1 will always pull the live rank otherwise we grab world
	def smart_world_rank
		#return (self.rankings.nil? || self.rankings.world_rank.nil? || self.rankings.world_rank <= 100 ? self.live_world_rank : self.world_rank) || 0
		return self.world_rank || 0
	end
	
	def smart_region_rank
		#return (self.rankings.nil? || self.rankings.region_rank.nil? || self.rankings.region_rank <= 100 ? self.live_region_rank : self.region_rank) || 0
		return self.region_rank || 0
	end
	
	# WORLD RANKINGS
	def world_rank(is_api=nil)
		return 0 if !is_api.nil? && ( self.rankings.nil? || self.rankings.world_rank.nil? )
		
		#return (self.rankings && !self.rankings.world_rank.nil? ? self.rankings.world_rank : self.live_world_rank) || 0
		return (self.rankings && !self.rankings.world_rank.nil? ? self.rankings.world_rank : 0) || 0
	end
	
	def live_world_rank
		return (Rails.cache.fetch("world/rank/#{self.bracket}/#{self.league}/#{self.is_random}/#{self.points}", :raw => true, :expires_in => 12.hours) do
			self.class.count(:all, :conditions => ["bracket = ? AND league = ? AND is_random = ? AND points >= ?", self.bracket, self.league, self.is_random, self.points])
		end).to_i
	end
	
	def world_competition
		return (Rails.cache.fetch(Digest::SHA1.hexdigest("ranks/list/#{self.bracket}/#{self.league}/#{self.is_random}//all"), :raw => true, :expires_in => 24.hours) do
			self.class.count(:all, :conditions => ["bracket = ? AND league = ? AND is_random = ?", self.bracket, self.league, self.is_random])
		end).to_i
	end

	def world_percentile
		return (self.world_rank || 0) / self.world_competition.to_f
	end
	
	# REGION RANKINGS
	def region_rank(is_api=nil)
		return 0 if !is_api.nil? && ( self.rankings.nil? || self.rankings.region_rank.nil? )

		#return (self.rankings && !self.rankings.region_rank.nil? ? self.rankings.region_rank : self.live_region_rank) || 0
		return (self.rankings && !self.rankings.region_rank.nil? ? self.rankings.region_rank : 0) || 0
	end
	
	def live_region_rank
		return (Rails.cache.fetch("#{self.region}/rank/#{self.bracket}/#{self.league}/#{self.is_random}/#{self.points}", :raw => true, :expires_in => 12.hours) do
			self.class.count(:all, :conditions => ["region = ? AND bracket = ? AND league = ? AND is_random = ? AND points >= ?", self.region, self.bracket, self.league, self.is_random, self.points])
		end).to_i
	end
		
	def region_competition
		return (Rails.cache.fetch(Digest::SHA1.hexdigest("ranks/list/#{self.bracket}/#{self.league}/#{self.is_random}/#{self.region}/all"), :raw => true, :expires_in => 24.hours) do
			self.class.count(:all, :conditions => ["region = ? AND bracket = ? AND league = ? AND is_random = ?", self.region, self.bracket, self.league, self.is_random])
		end).to_i
	end
	
	def region_percentile
		return (self.region_rank || 0) / self.region_competition.to_f
	end

	# RACE RANKINGS
	def race_percentile(character_id)
		self.team_characters.each do |relation|
			if relation.character_id == character_id
				return relation.race_region_rank / self.race_competition(relation.played_race).to_f
			end
		end
		
		return 0
	end
	
	def race_competition(race_id)
		return (Rails.cache.fetch("population/race/#{self.region}/#{self.bracket}/#{self.league}/#{self.is_random}/#{race_id}", :raw => true, :expires_in => 24.hours) do
			if self.is_random || self.bracket == 1
				race_id = race_id.to_s
				race_cond = "="
			else
				race_cond = "LIKE"
				race_id = "%#{race_id}%"
			end
			
			self.class.count(:all, :conditions => ["region = ? AND bracket = ? AND league = ? AND is_random = ? AND race_comp #{race_cond} ?", self.region, self.bracket, self.league, self.is_random, race_id]) || 0
		end).to_i
	end
	
	def favorite_race(character)
		team_char = self.team_characters.first(:conditions => {:character_id => character.id})
		return team_char && team_char.fav_race || -1
	end
end
