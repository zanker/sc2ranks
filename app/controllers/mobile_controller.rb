require "cgi"
class MobileController < ApplicationController
	def profile_find
		return render :error => 404 if params[:key] != "sc2ranks-mobile"
		
		character = Character.first(:conditions => ["region = ? AND name ILIKE ? AND character_code = ?", params[:region], CGI::unescape(params[:name]), params[:character_code].to_i])
		unless character
			return render :json => {:error => :no_character, :filters => {:region => params[:region], :name => params[:name], :character_code => params[:character_code]}}
		end
		
		data = {:id => character.id, :region => character.region, :name => character.name, :updated_at => character.updated_at.to_s(:js)}
		if character.character_code
			data[:character_code] = character.character_code
		end
			
		if character.portrait_id
			data[:portrait] = {
				:id => (character.portrait.icon_row * PORTRAITS_PER_ROW) + (character.portrait.icon_column + 1),
				:base_id => character.portrait.icon_id
			}
		end
		
		render :json => data
	end
		
	def profiles
		return render :error => 404 if params[:key] != "sc2ranks-mobile"
		
		character_ids = []
		if params[:characters]
			params[:characters].each do |character_id|
				character_id = character_id.to_i
				character_ids.push(character_id) if character_id > 0
			end
		end
		
		unless character_ids.length > 0
			return render :json => {:error => :no_profiles}
		end
		
		data = []
		Character.all(:conditions => ["id IN (?)", character_ids], :include => :portrait, :order => "name ASC").each do |character|
			char_data = {:id => character.id, :region => character.region, :name => character.name, :updated_at => character.updated_at.to_s(:js)}
			if character.character_code
				char_data[:character_code] = character.character_code
			end
				
			if character.portrait_id
				char_data[:portrait] = {
					:id => (character.portrait.icon_row * PORTRAITS_PER_ROW) + (character.portrait.icon_column + 1),
					:base_id => character.portrait.icon_id
				}
			end

			data.push(char_data)
		end
		
		render :json => data
	end
	
	def profile_modified
		return render :error => 404 if params[:key] != "sc2ranks-mobile"
		character_id = params[:character_id].to_i
		
		mobile = MobileProfile.first(:conditions => {:character_id => character_id, :device_id => params[:phoneID]})
		if params[:change] == "added" && mobile.nil?
			MobileProfile.create(:character_id => character_id, :device_id => params[:phoneID])
		elsif params[:change] == "removed" && mobile
			mobile.delete
		end
		
		render :nothing => true
	end

	def search
		return render :error => 404 if params[:key] != "sc2ranks-mobile"

		region = REGIONS.include?(params[:region]) ? params[:region] : nil
		name = CGI::unescape(params[:name])
		offset = params[:offset].to_i
		offset = 0 if offset < 0
				
		data = Rails.cache.fetch(Digest::SHA1.hexdigest("mobile/search/#{region}/#{name}/#{params[:match]}/#{offset}/#{Time.now.to_i}"), :expires_in => 30.minutes) do
			name = params[:match] == "contains" && "%#{name}%" || params[:match] == "starts" && "#{name}%" || params[:match] == "ends" && "%#{name}" || name
			conditions = region ? ["region = ? AND lower_name LIKE ?", region, name.downcase] : ["lower_name LIKE ?", name.downcase]

			total_chars = (Rails.cache.fetch(Digest::SHA1.hexdigest("mobile/search/total/#{region}/#{name}/#{params[:match]}/#{Time.now.to_i}"), :raw => true, :expires_in => 1.hour) do
				Character.count(:all, :conditions => conditions)
			end).to_i
			
			if total_chars > 0
				pagination = IPHONE_PAGINATION[:default];
				
				search_id = Digest::SHA1.hexdigest("#{region}/#{name}/#{params[:match]}/#{offset}/#{Time.now.to_i}")
				search = {:id => search_id, :total_chars => total_chars, :per_page => pagination, :offset => offset, :filters => {:region => region, :match => params[:match]}, :characters => []}
				Character.all(:conditions => conditions, :limit => pagination, :offset => offset, :include => :portrait).each do |character|
					char_data = {:id => character.id, :region => character.region, :name => character.name, :updated_at => character.updated_at.to_s(:js)}

					char_data[:character_code] = character.character_code unless character.character_code.nil?

					if character.portrait_id
						char_data[:portrait] = {
							:id => (character.portrait.icon_row * PORTRAITS_PER_ROW) + (character.portrait.icon_column + 1),
							:base_id => character.portrait.icon_id
						}
					end
					
					search[:characters].push(char_data)
				end
			else
				search = {:error => :no_characters}
			end
			
			search
		end
		
		render :json => data
	end
	
	def character
		return render :error => 404 if params[:key] != "sc2ranks-mobile"
		
		if params[:character_id]
			character = Character.first(:conditions => {:id => params[:character_id].to_i})
		elsif params[:bnet_id] && params[:region] && params[:name]
			character = Character.first(:conditions => {:region => params[:region], :bnet_id => params[:bnet_id].to_i})
			if character.nil?
				Armory::Queue.character(:region => params[:region], :bnet_id => params[:bnet_id].to_i, :name => CGI::unescape(params[:name]), :tag => 93)

				position = Armory::Job.queue_position({:class_name => "Jobs::Profile", :bnet_id => params[:bnet_id].to_i, :region => params[:region]}) || 0
			end
		elsif params[:region] && params[:character_code] && params[:name]
			character = Character.first(:conditions => {:region => params[:region], :character_Code => params[:character_code].to_i, :name => CGI::unescape(params[:name])})
		end
		
		if character.nil?
			unless position.nil?
				return render :json => {:queued => position}
			end
			
			return render :json => {:error => :no_character}
		end
		
		data = Rails.cache.fetch("mobile/character/#{character.cache_key}", :expires_in => 30.minutes) do
			# Try and keep character data for mobile fairly fresh
			if character.updated_at < 1.day.ago
				Armory::Queue.character(:region => character.region, :bnet_id => character.bnet_id, :name => character.name, :tag => 93)
			end
			
			# Sort it out into brackets
			team_brackets = {}
			character.teams.all.each do |team|
				bracket_id = team.bracket + (team.is_random ? 0.5 : 0)
				team_brackets[bracket_id] ||= []
				team_brackets[bracket_id].push({:id => team.id, :points => team.points, :league => LEAGUES[team.league], :bracket => team.bracket, :is_random => team.is_random, :world_rank => team.world_rank, :wins => team.wins, :losses => team.losses})
			end
			
			# And now shunt it back into the list
			teams = []
			team_brackets.keys.sort.each do |bracket|
				teams.push(team_brackets[bracket])
			end
			
			data = {
				:id => character.id,
				:region => character.region,
				:name => character.name,
				:achievement_points => character.achievement_points,
				:achieve_world => {
					:competition => character.achieve_world_competition,
					:rank => character.achieve_world_rank
				},
				:achieve_region => {
					:competition => character.achieve_region_competition,
					:rank => character.achieve_region_rank
				},
				:teams => teams,
				:updated_at => character.updated_at.to_s(:js)}
			
			if character.character_code
				data[:character_code] = character.character_code
			end
				
			if character.portrait_id
				data[:portrait] = {
					:id => (character.portrait.icon_row * PORTRAITS_PER_ROW) + (character.portrait.icon_column + 1),
					:base_id => character.portrait.icon_id
				}
			end
			
			data
		end
		
		render :json => data
	end
	
	def team
		return render :error => 404 if params[:key] != "sc2ranks-mobile"
		
		team_id = params[:team_id].to_i
		
		team = Team.first(:conditions => {:id => team_id})
		unless team and team.division
			return render :json => {:error => :no_team}
		end
		
		data = Rails.cache.fetch("mobile/team/#{team_id}/#{team.last_game_at.to_i}/#{team.updated_at.to_i}", :expires_in => 30.minutes) do
			#history = []
			#team.histories.all(:select => "*", :joins => "LEFT JOIN team_history_periods ON (team_histories.id >= team_history_periods.starts_at AND team_histories.id <= team_history_periods.ends_at)", :order => "team_histories.id DESC", :limit => 11).each do |record|
			#	next if record.created_at.nil?
			#	history.push({:league => LEAGUES[record.league], :world_rank => record.world_rank, :points => record.points, :created_at => Time.parse(record.created_at).to_s(:js)})
			#end
		
			characters = []
			team.team_characters.all(:include => :character).each do |relation|
				#characters.push({:fav_race => RACES[relation.played_race], :name => relation.character.name, :id => relation.character.id, :race_region_rank => relation.race_region_rank, :competition => team.race_competition(relation.played_race)});
				characters.push({:fav_race => RACES[relation.played_race], :name => relation.character.name, :id => relation.character.id, :race_region_rank => 0, :competition => 0})
			end
			
			data = {
				:id => team.id,
				:region => team.region,
				:league => LEAGUES[team.league],
				:points => team.points,
				:bracket => team.bracket,
				:is_random => team.is_random,
				:wins => team.wins,
				:losses => team.losses,
				:world_rank => {
					:place => team.smart_world_rank,
					:percentile => team.world_percentile.to_f,
					:competition => team.world_competition
				},
				:region_rank => {
					:place => team.smart_region_rank,
					:percentile => team.region_percentile.to_f,
					:competition => team.region_competition
				},
				:division => {
					:id => team.division.id,
					:rank => team.division_rank,
					:name => team.division.name,
				},
				:characters => characters,
				#:history => history,
				:updated_at => team.division.updated_at.to_s(:js),
				:last_game_at => team.last_game_at.to_s(:js),				
			}
			
			data
		end
		
		render :json => data
	end
	
	def rankings
		return render :error => 404 if params[:key] != "sc2ranks-mobile"
		
		# League specific filters
		region = REGIONS.include?(params[:region]) ? params[:region] : nil
		league = LEAGUES[params[:league]] && LEAGUES[params[:league]] || params[:league] != "all" && LEAGUES["master"] || nil
		bracket = BRACKETS.include?(params[:bracket].to_i) ? params[:bracket].to_i : 1
		is_random = params[:is_random] == "1" ? true : false
		race = params[:race] && RACES[params[:race]] || nil
		
		# Misc display
		sort_by = params[:sort] == "ratio" && "win_ratio" || params[:sort] == "comp" && "race_comp" || params[:sort] == "pointratio" && "(points * win_ratio)" || params[:sort] == "wins" && "wins" || params[:sort] == "losses" && "losses" || params[:sort] == "played" && "(wins + losses)" || params[:sort] && "points"
		offset = params[:offset].to_i
		offset = 0 if offset < 0

		# Build query!
		query = ["bracket = :bracket AND is_random = :random AND teams.division_id IS NOT NULL", {:bracket => bracket, :random => is_random}]
		if region
			query[0] << " AND teams.region = :region"
			query[1][:region] = region
		end
		
		if league
			query[0] << " AND league = :league"
			query[1][:league] = league
		end
		
		if race
			if bracket == 1 || is_random
				query[0] << " AND race_comp = :race"
				query[1][:race] = race.to_s
			else
				query[0] << " AND race_comp LIKE :race"
				query[1][:race] = "%#{race}%"
			end
		end

		# No sense in repulling total teams because that won't change
		total_teams = (Rails.cache.fetch(Digest::SHA1.hexdigest("ranks/list/#{bracket}/#{league}/#{is_random}/#{region}/#{race}"), :raw => true, :expires_in => 20.minutes) do
			Team.count(:all, :conditions => query) || 0
		end).to_i
		
		pagination = IPHONE_PAGINATION[:default];
		offset = offset > total_teams ? (total_teams - pagination) : offset
		offset = offset < 0 ? 0 : offset
		
		rank_id = Digest::SHA1.hexdigest("#{bracket}/#{league}/#{is_random}/#{region}/#{race}/#{sort_by || "points"}/#{offset}")
		
		# Base shell of what we want to tell the client
		data = {:rankings => [], :id => rank_id, :total_teams => total_teams, :per_page => pagination, :offset => offset, :filters => {:league => league || "all", :region => region || "all", :is_random => is_random, :bracket => bracket, :race => race || "all", :sort_by => sort_by || "points"}}
		
		# Add teams
		previous_points = nil
		rank, skipped_increments = 0, 0
		Team.all(:conditions => query, :order => "#{sort_by || "points"} DESC", :limit => pagination, :offset => offset, :include => [:division, :team_characters, :characters, :rankings]).each do |team|
			# Ranking
			if previous_points.nil? || previous_points != team.points
				rank += 1 + skipped_increments
				skipped_increments = 0
			else
				skipped_increments += 1
			end
			previous_points = team.points
			
			# Team data
			team_data = {:rank => rank,  :league => LEAGUES[team.league], :region => team.region, :points => team.points, :wins => team.wins, :losses => team.losses, :ratio => team.win_ratio, :id => team.id, :characters => []}
			
			team.team_characters.each do |relation|
				character = relation.character
				next unless character
				
				team_data[:characters].push({
					:id => character.id,
					:name => character.name,
					:fav_race => RACES[relation.played_race],
				})
			end
			
			data[:rankings].push(team_data)
		end
		
		render :json => data
	end
end
