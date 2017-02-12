class Stats < ActiveRecord::Base
	def self.validate_params(params)
		# Bracket
		is_random, bracket = nil, nil
		if params[:bracket] && params[:bracket].downcase != "all"
			is_random = params[:bracket].match(/r/i) ? true : false
			if is_random
				bracket = params[:bracket].match(/([0-9]+)/)[1].to_i
			else
				bracket = params[:bracket].to_i
			end
			
			bracket = nil unless BRACKETS.include?(bracket)
		end
		
		# Region
		region = params[:region] && params[:region].downcase
		if region != "all"
			region = RANK_REGIONS_LIST.include?(region) ? region : nil
		elsif region == "all"
			region = nil
		end
		
		# Player group/top players
		player_group = params[:group].to_i
		player_group = player_group > 0 && player_group <= 5000 ? player_group : nil
		
		# League
		league = params[:league] && params[:league].downcase
		if league
			league = LEAGUES[league] ? league : nil
		elsif league == "all"
			league = nil
		end
		
		# Patch
		patch = LATEST_PATCH
		if params[:patch]
			patch = params[:patch].to_i
			patch = PATCHES[patch] ? patch : LATEST_PATCH
		end
		
		# Activity
		activity = patch == LATEST_PATCH && params[:activity].to_i > 0 ? params[:activity].to_i : nil
		
		expansion = CURRENT_EXPANSION
		if params.has_key?(:expansion)
			expansion = EXPANSIONS[params[:expansion].to_i] ? params[:expansion].to_i : CURRENT_EXPANSION
		end

		return bracket, is_random, region, league, player_group, patch, activity, expansion
	end
	
	def self.get_team(patch)
		return TeamsFromPatch.send("p#{patch || LATEST_PATCH}")
	end
	
	def self.team_name(patch)
		return patch && PATCHES[patch] && patch != LATEST_PATCH && "teams_patch_#{patch}" || "teams"
	end
	
	# Create filters for player groups
	def self.build_group(args)
		team_name = self.team_name(args[:patch])
		group = {:filter => [], :conditions => []}
		args[:group].each do |value|
			if args[:bracket]
				conditions = ["#{team_name}.bracket = ? AND #{team_name}.is_random = ? AND #{team_name}.#{args[:group_key]} = ?", args[:bracket], args[:is_random], value]
			else
				conditions = ["#{team_name}.#{args[:group_key]} = ?", value]
			end
			
			if args[:region]
				conditions[0] << " AND #{team_name}.region = ?"
				conditions.push(args[:region])
			end
			
			# SELECT * FROM teams WHERE league = 4 AND bracket = 1 ANd is_random = false ORDER BY points DESC LIMIT 1 OFFSET 49
			team = self.get_team(args[:patch]).first(:conditions => conditions, :order => "points DESC", :limit => 1, :offset => args[:limit] - 1)
			if team
				group[:filter].push("( #{team_name}.#{args[:group_key]} = ? AND #{team_name}.points >= ? )")
				group[:conditions].push(value)
				group[:conditions].push(team.points)
			end
		end
		
		return group[:conditions].length > 1 ? group : nil
	end
	
	# Build conditions
	def self.build_conditions(args)
		conditions = [""]
		if args[:expansion] and self.team_name(args[:patch]) == "teams"
			conditions[0] << "teams.expansion = ?"
			conditions.push(args[:expansion])
		end	
	
		if args[:region]
			conditions[0] << "#{args[:region_on] || ""}region = ?"
			conditions.push(args[:region])
		end
		
		if args[:bracket]
			conditions[0] << " AND " unless conditions[0].blank?
			conditions[0] << " #{self.team_name(args[:patch])}.bracket = ? AND #{self.team_name(args[:patch])}.is_random = ?"
			conditions.push(args[:bracket], args[:is_random])
		end
			
		if args[:group]
			group = build_group(args)
			if group
				conditions[0] << " AND" unless conditions[0].blank?
				conditions[0] << " (#{group[:filter].join(" OR ")})"
				conditions = conditions + group[:conditions]
			end
		end
		
		if args[:activity] && args[:patch] == LATEST_PATCH
			conditions[0] << " AND " unless conditions[0].blank?
			conditions[0] << "#{self.team_name(args[:patch])}.last_game_at >= ?"
			conditions.push(args[:activity].days.ago)
		end
		
		if args[:games]
			conditions[0] << " AND " unless conditions[0].blank?
			conditions[0] << "(#{self.team_name(args[:patch])}.wins + #{self.team_name(args[:patch])}.losses) >= ?"
			conditions.push(args[:games])
		end
		
		if self.team_name(args[:patch]) == "teams"
			conditions[0] << " AND " unless conditions[0].blank?
			conditions[0] << "teams.division_id IS NOT NULL"
		end
		
		return conditions.length > 1 ? conditions : nil
	end
	
	# Total number of results returned
	def self.team_totals(args)
		return self.get_team(args[:patch]).count(:conditions => self.build_conditions(args)) || 0
	end
	
	# Race population by point slices
	def self.race_by_points(args)
		conditions = ["points > 0 AND league = ?", args[:league]]

		if args[:region]
			conditions[0] += " AND region = ?"
			conditions.push(args[:region])
		end
		
		if args[:bracket]
			conditions[0] += " AND bracket = ? AND is_random = ?"
			conditions.push(args[:bracket])
			conditions.push(args[:is_random])
		end
		
		if args[:expansion] and self.team_name(args[:patch]) == "teams"
			conditions[0] += " AND expansion = ?"
			conditions.push(args[:expansion])
		end	
	
		races = {:total => 0}
		self.get_team(args[:patch]).all(:select => "COUNT(*) as total, race_comp, points", :conditions => conditions, :group => "race_comp, points").each do |team|
			team.race_comp.split("/").each do |race|
				race = race.to_i
				
				races[race] ||= {}
				races[race][team.points.to_i] ||= 0
				races[race][team.points.to_i] += team.total.to_i

				races[:total] += team.total.to_i
			end
		end
		return races
	end
	
	# League populations
	def self.league_population(args)
		stats = {:total => 0}
		self.get_team(args[:patch]).all(:select => "COUNT(*) as total, league", :conditions => args[:region] && {:region => args[:region]}, :group => "league").each do |team|
			stats[:total] += team.total.to_i
			
			stats[team.league.to_i] ||= 0
			stats[team.league.to_i] += team.total.to_i
		end
		
		return stats
	end
	
	# League split by region
	def self.leagues_by_regions(args)
		leagues = {"global" => {:total => 0}}
		self.get_team(args[:patch]).all(:select => "COUNT(*) as total, league, region", :conditions => build_conditions(args), :group => "region, league").each do |team|
			self.add_league_stat(leagues, team.region, team.league.to_i, team.total.to_i)
			self.add_league_stat(leagues, "global", team.league.to_i, team.total.to_i)
		end
		
		return leagues
	end
		
	# Query for pulling race data, odds are you going to call both of them so it's easier to pull a little more data initially and let the query cacher handle it
	def self.race_league_query(args)
		return self.get_team(args[:patch]).all(:select => "COUNT(*) as total, SUM(wins) as total_wins, SUM(losses) as total_losses, SUM(points) as total_points, league, race_comp", :conditions => build_conditions(args), :group => "league, race_comp")
	end

	# Race split by league
	def self.race_by_leagues(args)
		leagues = {}
		self.race_league_query(args).each do |team|
			team.race_comp.split("/").each do |race|
				self.add_league_stat(leagues, team.league.to_i, race.to_i, team.total.to_i)
				self.add_league_stat(leagues, "global", race.to_i, team.total.to_i)
			end
		end
		
		return leagues
	end
	
	# Race win split by league
	def self.race_wins_by_leagues(args)
		races = {}
		
		self.race_league_query(args).each do |team|
			team.race_comp.split("/").each do |race|
				self.add_race_win_stats(races, team.league.to_i, race.to_i, team.total_wins.to_i, team.total_losses.to_i)
			end
		end
		
		return races
	end

	# Race average points by league
	def self.race_points_by_leagues(args)
		races = {}
		self.race_league_query(args).each do |team|
			team.race_comp.split("/").each do |race|
				self.add_points_stat(races, team.league.to_i, race.to_i, team.total, team.total_points)
			end
		end

		return self.calculate_points(races)
	end
	
	# Race region query, same deal as the league one
	def self.race_region_query(args)
		return self.get_team(args[:patch]).all(:select => "COUNT(*) as total, SUM(wins) as total_wins, SUM(losses) as total_losses, SUM(points) as total_points, race_comp, region", :conditions => build_conditions(args), :group => "region, race_comp")
	end
	
	# Race global query
	def self.race_group_global_query(args)
		lowest_team = self.get_team(args[:patch]).first(:conditions => ["bracket = ? AND is_random = ?", args[:bracket], args[:is_random]], :order => "points DESC", :limit => 1, :offset => args[:limit] - 1)
		return [] if lowest_team.nil?

		return self.get_team(args[:patch]).all(:select => "COUNT(*) as total, SUM(wins) as total_wins, SUM(losses) as total_losses, SUM(points) as total_points, race_comp, region", :conditions => ["bracket = ? AND is_random = ? AND points >= ?", args[:bracket], args[:is_random], lowest_team.points], :group => "region, race_comp")
	end
	
	# Races by region
	def self.race_by_regions(args)
		races = {}
		self.race_region_query(args).each do |team|
			team.race_comp.split("/").each do |race|
				self.add_league_stat(races, team.region, race.to_i, team.total.to_i)
				
				unless args[:group]
					self.add_league_stat(races, "global", race.to_i, team.total.to_i)
				end
			end
		end

		# Global for groups has to be done separately
		if args[:group]
			self.race_group_global_query(args).each do |team|
				team.race_comp.split("/").each do |race|
					self.add_league_stat(races, "global", race.to_i, team.total.to_i)
				end
			end
		end
				
		return races
	end
	
	# Race points by region
	def self.race_points_by_regions(args)
		races = {}
		self.race_region_query(args).each do |team|
			team.race_comp.split("/").each do |race|
				self.add_points_stat(races, team.region, race.to_i, team.total, team.total_points)

				unless args[:group]
					self.add_points_stat(races, "global", race.to_i, team.total, team.total_points)
				end
			end
		end
		
		# Global for groups has to be done separately
		if args[:group]
			self.race_group_global_query(args).each do |team|
				team.race_comp.split("/").each do |race|
					self.add_points_stat(races, "global", race.to_i, team.total, team.total_points)
				end
			end
		end
		
		return self.calculate_points(races)
	end
		
	# Race win split by region
	def self.race_wins_by_regions(args)
		races = {}
		self.race_region_query(args).each do |team|
			team.race_comp.split("/").each do |race|
				self.add_race_win_stats(races, team.region, race.to_i, team.total_wins.to_i, team.total_losses.to_i)

				unless args[:group]
					self.add_race_win_stats(races, "global", race.to_i, team.total_wins.to_i, team.total_losses.to_i)
				end
			end
		end
		
		# Global for groups has to be done separately
		if args[:group]
			self.race_group_global_query(args).each do |team|
				team.race_comp.split("/").each do |race|
					self.add_race_win_stats(races, "global", race.to_i, team.total_wins.to_i, team.total_losses.to_i)
				end
			end
		end
		
		return races
	end
		
	
	# Misc adders
	private
		def self.add_race_win_stats(races, primary, secondary, wins, losses)
			races[primary] ||= {}
			races[primary][secondary] ||= {:total => 0, :wins => 0, :teams => 0}
			races[primary][secondary][:total] += wins + losses
			races[primary][secondary][:wins] += wins
		end

		def self.add_league_stat(leagues, primary, secondary, total)
			leagues[primary] ||= {:total => 0}
			leagues[primary][:total] += total

			leagues[primary][secondary] ||= 0
			leagues[primary][secondary] += total
		end

		
		def self.add_points_stat(races, primary, secondary, teams, points)
			races[primary] ||= {}
			races[primary][secondary] ||= {:teams => 0, :points => 0, :average => 0}
			races[primary][secondary][:points] += points.to_i
			races[primary][secondary][:teams] += teams.to_i
		end
		
		def self.calculate_points(races)
			races.each do |primary, list|
				list.each do |secondary, stat|
					stat[:average] = stat[:teams] > 0 ? (stat[:points].to_f / stat[:teams]).round : 0
				end
			end
			
			return races
		end
end
