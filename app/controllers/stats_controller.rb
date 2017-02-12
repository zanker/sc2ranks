class StatsController < ApplicationController
	def format_url
		if params[:statfilter].nil? || params[:statfilter][:type] == "summary"
			redirect_to stats_path
		elsif params[:statfilter][:type] == "name"
			redirect_to stats_name_path(params[:statfilter][:region] || "all", params[:statfilter][:league] || "all", params[:statfilter][:bracket])
		elsif params[:statfilter][:type] == "achievements"
			redirect_to stats_achievements_path(params[:statfilter][:region] || "all")
		elsif params[:statfilter][:type] == "region"
			redirect_to stats_region_path(params[:statfilter][:league] || "all", params[:statfilter][:bracket], params[:statfilter][:group], params[:statfilter][:activity], 0, params[:statfilter][:expansion])
		elsif params[:statfilter][:type] == "league"
			redirect_to stats_league_path(params[:statfilter][:region] || "all", params[:statfilter][:bracket], params[:statfilter][:group], params[:statfilter][:activity], 0, params[:statfilter][:expansion])
		elsif params[:statfilter][:type] == "race"
			redirect_to stats_race_path(params[:statfilter][:region] || "all", params[:statfilter][:bracket], params[:statfilter][:activity], 0, params[:statfilter][:expansion])
		else
			redirect_to stats_path
		end
	end
	
	# Name popularity
	def name
		@bracket, @is_random, @region, @league, @player_group, @patch = Stats.validate_params(params)
		@page_hash = Digest::SHA1.hexdigest("stat/name/#{@league}/#{@bracket}/#{@is_random}/#{@region}")
		
		etag = Rails.cache.read("#{@page_hash}/etag", :raw => true, :expires_in => 1.day) 
		return unless etag.nil? || stale?(:etag => etag)
		
		unless read_fragment(@page_hash, :raw => true, :expires_in => 1.day)
			Rails.cache.write("#{@page_hash}/etag", "#{@page_hash}/#{Time.now.to_i}", :raw => true, :expires_in => 1.day)
			
			conditions = Stats.build_conditions(:region => @region, :region_on => "characters.", :is_random => @is_random, :bracket => @bracket)

			if @bracket || @is_random || @league
				iterator = Character.all(:select => "characters.name, COUNT(*) as total", :conditions => conditions, :joins => "LEFT JOIN team_characters ON team_characters.character_id=characters.id LEFT JOIN teams ON teams.id=team_characters.team_id", :limit => 100, :order => "total DESC", :group => "characters.name")
			else
				iterator = Character.all(:select => "name, COUNT(*) as total", :conditions => @region && {:region => @region}, :order => "total DESC", :group => "name", :limit => 100)
			end
			
			@names = []
			iterator.each do |name|
				@names.push({:name => name.name, :total => name.total.to_i})
			end
		end
	end
	
	# Achievement percentages
	def achievements
		@region = RANK_REGIONS_LIST.include?(params[:region]) ? params[:region] : nil
		@category_id = ACHIEVEMENT_CATEGORIES[params[:category_id].to_i] ? params[:category_id].to_i : ACHIEVEMENT_DEFAULT
		
		@page_hash = Digest::SHA1.hexdigest("stat/achievements/#{@region}/#{@category_id}")
		
		unless read_fragment(@page_hash, :raw => true, :expires_in => 1.day)
			@total_players = Character.count(:conditions => (@region ? ["updated_achievements IS NOT null AND region = ?", @region] : ["updated_achievements IS NOT null"]))

			@achievements = []
			@achievement_totals = {}

			# Grab achievement info
			achievement_ids = []
			Achievement.all(:conditions => {:category_id => @category_id, :is_parent => false}).each do |achievement|
				@achievement_totals[achievement.achievement_id] = 0
				@achievements.push(achievement)
				
				achievement_ids.push(achievement.achievement_id)
			end
			
			# Figure out how many have this, do two different queries based on region since one doesn't need a join
			if @region
				iteration = CharacterAchievement.all(:select => "COUNT(*) as total_earned, character_achievements.achievement_id", :conditions => ["characters.region = ? AND character_achievements.achievement_id IN(?)", @region, achievement_ids], :joins => "LEFT JOIN characters ON characters.id = character_achievements.character_id", :group => "character_achievements.achievement_id")
			else
				iteration = CharacterAchievement.all(:select => "COUNT(*) as total_earned, achievement_id", :conditions => ["achievement_id IN(?)", achievement_ids], :group => "achievement_id")
			end
			
			iteration.each do |achievement|
				@achievement_totals[achievement.achievement_id.to_i] = achievement.total_earned.to_i
			end
			
			@achievements.sort!{|a, b| @achievement_totals[a.achievement_id] <=> ( b && @achievement_totals[b.achievement_id] || 999999 ) }
		end
	end
	
	# Stats changes
	def overall_changes
		@page_hash = Digest::SHA1.hexdigest("stat/changes")
				
		etag = Rails.cache.read("#{@page_hash}/etag", :raw => true, :expires_in => 1.hour) 
		return unless etag.nil? || stale?(:etag => etag)
		
		unless read_fragment(@page_hash, :raw => true, :expires_in => 1.hour)
			Rails.cache.write("#{@page_hash}/etag", "#{@page_hash}/#{Time.now.to_i}", :raw => true, :expires_in => 1.hour)
			
			@population = {}
			Stats.all(:conditions => ["stat_type = ? AND created_at >= ?", STAT_TYPES["population-by-region"], 1.month.ago.utc]).each do |stats|
				@population[stats.region] ||= []
				@population[stats.region].push([stats.created_at, stats.stat_number])
			end
		end
	end
	
	# Region stats
	def region
		@bracket, @is_random, @region, @league, @player_group, @patch, @activity, @expansion = Stats.validate_params(params)
		@page_hash = Digest::SHA1.hexdigest("statss/region/#{@bracket}/#{@is_random}/#{@league}/#{@player_group}/#{@patch}/#{@activity}/#{@expansion}")
				
		etag = Rails.cache.read("#{@page_hash}/etag", :raw => true, :expires_in => 1.day) 
		return unless etag.nil? || stale?(:etag => etag)
		
		unless read_fragment(@page_hash, :raw => true, :expires_in => 1.day)
			Rails.cache.write("#{@page_hash}/etag", "#{@page_hash}/#{Time.now.to_i}", :raw => true, :expires_in => 1.day)
			
			@player_total = Stats.team_totals(:bracket => @bracket, :is_random => @is_random, :patch => @patch, :activity => @activity, :expansion => @expansion)

			@regions = {}

			unless @player_group || @league
				@regions[:leagues] = Stats.leagues_by_regions(:bracket => @bracket, :is_random => @is_random, :patch => @patch, :activity => @activity, :expansion => @expansion)
			end
			
			@regions[:races] = Stats.race_by_regions(:bracket => @bracket, :is_random => @is_random, :group => @player_group && RANK_REGIONS_LIST, :group_key => "region", :limit => @player_group, :expansion => @expansion, :patch => @patch, :activity => @activity)
			@regions[:race_wins] = Stats.race_wins_by_regions(:bracket => @bracket, :is_random => @is_random, :group => @player_group && RANK_REGIONS_LIST, :group_key => "region", :limit => @player_group, :patch => @patch, :expansion => @expansion, :activity => @activity)
			@regions[:race_points] = Stats.race_points_by_regions(:bracket => @bracket, :is_random => @is_random, :group => @player_group && RANK_REGIONS_LIST, :group_key => "region", :limit => @player_group, :patch => @patch, :activity => @activity, :expansion => @expansion)
		end		
	end
	
	# League stats
	def league
		@bracket, @is_random, @region, @league, @player_group, @patch, @activity, @expansion = Stats.validate_params(params)
		@games = params[:games].to_i
		@page_hash = Digest::SHA1.hexdigest("statss/league/#{@bracket}/#{@is_random}/#{@region}/#{@expansion}/#{@player_group}/#{@patch}/#{@activity}/#{@games}/#{@expansion}")
		
		etag = Rails.cache.read("#{@page_hash}/etag", :raw => true, :expires_in => 1.day) 
		return unless etag.nil? || stale?(:etag => etag)
		
		unless read_fragment(@page_hash, :raw => true, :expires_in => 1.day)
			Rails.cache.write("#{@page_hash}/etag", "#{@page_hash}/#{Time.now.to_i}", :raw => true, :expires_in => 1.day)
			
			@player_total = Stats.team_totals(:region => @region, :bracket => @bracket, :is_random => @is_random, :patch => @patch, :activity => @activity, :games => @games, :expansion => @expansion)

			@regions = {}
			@leagues = {}
			
			unless @player_group
				@regions[:leagues] = Stats.leagues_by_regions(:bracket => @bracket, :is_random => @is_random, :patch => @patch, :activity => @activity, :games => @games, :expansion => @expansion)
			end

			@leagues[:races] = Stats.race_by_leagues(:region => @region, :bracket => @bracket, :is_random => @is_random, :group => @player_group && LEAGUE_LIST, :group_key => "league", :limit => @player_group, :expansion => @expansion, :patch => @patch, :activity => @activity, :games => @games)
			@leagues[:race_wins] = Stats.race_wins_by_leagues(:region => @region, :bracket => @bracket, :is_random => @is_random, :group => @player_group && LEAGUE_LIST, :group_key => "league", :limit => @player_group, :patch => @patch, :expansion => @expansion, :activity => @activity, :games => @games)
			@leagues[:race_points] = Stats.race_points_by_leagues(:region => @region, :bracket => @bracket, :is_random => @is_random, :group => @player_group && LEAGUE_LIST, :group_key => "league", :limit => @player_group, :patch => @patch, :activity => @activity, :expansion => @expansion, :games => @games)
		end
	end
	
	# Race stats
	def race
		@bracket, @is_random, @region, @league, @player_group, @patch, @activity, @expansion = Stats.validate_params(params)
		@page_hash = Digest::SHA1.hexdigest("statss/race/#{@bracket}/#{@is_random}/#{@region}/#{@expansion}/#{@patch}/#{@activity}/#{@expansion}")
				
		etag = Rails.cache.read("#{@page_hash}/etag", :raw => true, :expires_in => 1.day) 
		return unless etag.nil? || stale?(:etag => etag)
		
		unless read_fragment(@page_hash, :raw => true, :expires_in => 1.day)
			Rails.cache.write("#{@page_hash}/etag", "#{@page_hash}/#{Time.now.to_i}", :raw => true, :expires_in => 1.day)
			
			@player_total = Stats.team_totals(:region => @region, :bracket => @bracket, :is_random => @is_random, :expansion => @expansion, :patch => @patch, :activity => @activity)
			
			@races = {}
			@stats = {}
			
			LEAGUE_LIST.each do |league|
				@races[league] = Stats.race_by_points(:region => @region, :bracket => @bracket, :is_random => @is_random, :league => league, :expansion => @expansion, :patch => @patch, :activity => @activity)
				
				@stats[league] = @races[league][:total]
				@races[league].delete(:total)
			end
		end
	end
	
	# Old index page, our new simple summary
	def summary_index
		@bracket, @is_random, @region, @player_group = Stats.validate_params(params)

		@page_hash = Digest::SHA1.hexdigest("statss/#{@bracket}/#{@is_random}/#{@region}/#{@player_group}")
		
		etag = Rails.cache.read("#{@page_hash}/etag", :raw => true, :expires_in => 1.day) 
		return unless etag.nil? || stale?(:etag => etag)
		
		unless read_fragment(@page_hash, :raw => true, :expires_in => 1.day)
			Rails.cache.write("#{@page_hash}/etag", "#{@page_hash}/#{Time.now.to_i}", :raw => true, :expires_in => 1.day)

			@leagues = {}
			@regions = {}
			@stats = {}
			
			unless @bracket
				@stats[:total] = Character.count(:all, :conditions => @region ? {:region => @region} : nil).to_i
			end
			
			# LEAGUE STATS
			@leagues[:races] = Stats.race_by_leagues(:region => @region, :bracket => @bracket, :is_random => @is_random, :group => @player_group && LEAGUE_LIST, :group_key => "league", :limit => @player_group)
			@leagues[:race_wins] = Stats.race_wins_by_leagues(:region => @region, :bracket => @bracket, :is_random => @is_random, :group => @player_group && LEAGUE_LIST, :group_key => "league", :limit => @player_group)
			@leagues[:race_points] = Stats.race_points_by_leagues(:region => @region, :bracket => @bracket, :is_random => @is_random, :group => @player_group && LEAGUE_LIST, :group_key => "league", :limit => @player_group)
			
			# REGION STATS
			unless @region
				unless @player_group
					@regions[:leagues] = Stats.leagues_by_regions(:bracket => @bracket, :is_random => @is_random)
				end
				
				@regions[:race_points] = Stats.race_points_by_regions(:bracket => @bracket, :is_random => @is_random, :group => @player_group && RANK_REGIONS_LIST, :group_key => "region", :limit => @player_group)
				@regions[:race_wins] = Stats.race_wins_by_regions(:bracket => @bracket, :is_random => @is_random, :group => @player_group && RANK_REGIONS_LIST, :group_key => "region", :limit => @player_group)
				@regions[:races] = Stats.race_by_regions(:bracket => @bracket, :is_random => @is_random, :group => @player_group && RANK_REGIONS_LIST, :group_key => "region", :limit => @player_group)
			end
		end
	end
end
