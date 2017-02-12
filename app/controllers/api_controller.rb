require "cgi"
class ApiController < ApplicationController
	def rankings
		return render :json => {:error => "no_key"} unless params[:appKey] == "ign.com"
	
    expansion = CURRENT_EXPANSION
    if params.has_key?(:expansion)
      expansion = EXPANSIONS[params[:expansion].to_i] ? params[:expansion].to_i : CURRENT_EXPANSION
    end

		
		list = []
		placement = 0
		previous_points = nil
		skipped_increments = 0
		Team.all(:conditions => {:expansion => expansion, :season => current_season, :region => params[:region]}, :limit => 200, :order => "points DESC", :include => [:division, :team_characters, :characters]).each do |team|
			next if team.division_id.nil?
			
			if previous_points.nil? || previous_points != team.points
				placement += 1 + skipped_increments
				skipped_increments = 0
			else
				skipped_increments += 1
			end
			previous_points = team.points

			character = team.characters.first
			next unless character

			data = {:expansion => expansion, :points => team.points, :wins => team.wins, :losses => team.losses, :rank => placement, :team_url => team_url(team.id), :division => team.division.name, :division_url => rank_division_url(team.division.id, parameterize(team.division.name)), :last_updated => team.division.updated_at}
			data[:character] = {:url => character_url(character.region, character.bnet_id, character.name), :tag => character.tag, :name => character.name}
			
			list.push(data)
		end
		
		return render :json => list
	end
	
	def name_map
		if params[:appKey].blank?
			return render :json => {:error => "no_key"}
		end
		
		names = (Rails.cache.fetch("names/map", :expires_in => 30.minutes) do
			list = {}
			Vod.all(:select => "player_one, char_one.bnet_id as one_bnet_id, char_one.region as one_region, char_one.name as one_name, player_two, char_two.bnet_id as two_bnet_id, char_two.region as two_region, char_two.name as two_name, char_two.tag as two_tag, char_one.tag as one_tag", :conditions => ["char_one.id IS NOT NULL or char_two.id IS NOT NULL"], :joins => "LEFT JOIN characters AS char_one ON char_one.id=player_one_id LEFT JOIN characters AS char_two ON char_two.id=player_two_id").each do |vod|
				if vod["one_bnet_id"] && list[vod["player_one"]].nil?
					list[vod["player_one"]] = {:region => vod["one_region"], :bnet_id => vod["one_bnet_id"], :name => vod["one_name"], :tag => vod["one_tag"]}
				end
				
				if vod["two_bnet_id"] && list[vod["player_two"]].nil?
					list[vod["player_two"]] = {:region => vod["two_region"], :bnet_id => vod["two_bnet_id"], :name => vod["two_name"], :tag => vod["two_tag"]}
				end
			end
			
			list
		end)
		
		render :json => names
	end
	
	def profile_search
		if params[:appKey].blank? || ( params[:name] == "Shadowed" && ( params[:appKey] == "sc2ranks.com" || params[:appKey] == "example.com" ) )
			respond_to do |wants|
				wants.json { render :json => {:error => "no_key"} }
				wants.xml { render :xml => {:error => "no_key"} }
			end
			return
		end
		
		region = REGIONS.include?(params[:region].downcase) ? params[:region].downcase : "us"
		name = CGI::unescape(params[:name])
		type = params[:type].downcase
		sub_type = params[:sub_type].downcase
		value = sub_type != "division" ? params[:value].to_i : CGI::unescape(params[:value])
		
		bracket = type.match("([0-9]+)")
		bracket = bracket && bracket[0].to_i > 0 ? bracket[0].to_i : nil
		
		if bracket
			sub_type = sub_type == "wins" && "wins" || sub_type == "losses" && "losses" || sub_type == "division" && "division" || "points"
		else
			sub_type = "points"
		end
			
		data = (Rails.cache.fetch(Digest::SHA1.hexdigest("api/profile/search/#{region}/#{name}/#{type}/#{sub_type}/#{value}"), :expires_in => 30.minutes) do
			conditions = ["characters.region = ? AND characters.lower_name = ?", region, name.downcase]

			joins = nil
			if bracket
				season = current_season

				joins = "LEFT JOIN team_characters ON team_characters.character_id = characters.id LEFT JOIN teams ON teams.id = team_characters.team_id"

				conditions[0] << "AND teams.division_id IS NOT NULL AND teams.bracket = ?"
				conditions.push(bracket)
					
				conditions[0] << " AND teams.season = ?"
				conditions.push(season)
						
				if sub_type == "division"
					joins << " LEFT JOIN divisions ON divisions.id=teams.division_id"
					
					conditions[0] << " AND divisions.name ILIKE ?"
					conditions.push("%#{value}%")
				else
					conditions[0] << " AND teams.#{sub_type} <= ? AND teams.#{sub_type} >= ?"
					conditions.push(value + 50, value - 50)
				end
			else
				conditions[0] << " AND characters.achievement_points <= ? AND characters.achievement_points >= ?"
				conditions.push(value + 100, value - 100)
			end
						
			char_list = []
			Character.all(:select => "characters.id, characters.name, characters.region, characters.tag, characters.character_code, characters.bnet_id, characters.achievement_points", :conditions => conditions, :joins => joins, :include => {:teams => :division}, :limit => 100).each do |character|
				team = nil
				character.teams.each do |team_data|
					next if team_data.division_id.nil?
					
					if bracket
						team = team_data if team.nil? || team_data.bracket == bracket
					else
						team = team_data if team_data && ( team.nil? || team.points < team_data.points || team.league < team_data.league )
					end
				end
				
				next if team.nil?
				
				char_data = {:id => character.id, :tag => character.tag, :name => character.name, :region => character.region, :bnet_id => character.bnet_id, :achievement_points => character.achievement_points}
				char_data[:character_code] = character.character_code unless character.character_code.blank?
				char_data[:team] = {:id => team.id, :points => team.points, :division_id => team.division.id, :division_name => team.division.name, :wins => team.wins, :losses => team.losses, :expansion => team.expansion}
				
				char_list.push(char_data)
			end
			
			char_list
		end)
		
		if data.length == 0
			data = {:error => "no_character"}
		end
		
		respond_to do |wants|
			wants.json { render :json => data }
			wants.xml { render :xml => data }
		end
	end
	
	
	# Total bonus pools per region
	def bonus_pools
		if params[:appKey].blank?
			respond_to do |wants|
				wants.json { render :json => {:error => "no_key"} }
				wants.xml { render :xml => {:error => "no_key"} }
			end
			return
		end
		
		totals = {}
		RegionBonusPool.all.each do |pool|
			totals[pool.region] = pool.max_pool
		end
		
		respond_to do |wants|
			wants.json { render :json => totals }
			wants.xml { render :xml => totals }
		end
	end
	
	# Map popularity for one map
	def single_map_popularity
		if params[:appKey].blank?
			respond_to do |wants|
				wants.json { render :json => {:error => "no_key"} }
				wants.xml { render :xml => {:error => "no_key"} }
			end
			return
		end
		
		map_games = {}
		MatchTotal.all(:conditions => {:map_id => params[:map_id].to_i}).each do |match|
			next if match.stat_date.nil?
			map_games[match.stat_date.strftime("%Y-%m-%d")] = match.total_games
		end

		respond_to do |wants|
			wants.json { render :json => map_games }
			wants.xml { render :xml => map_games }
		end
	end
	
	# Map popularity for sc2mapster
	def map_popularity
		region = REGIONS.include?(params[:region]) && params[:region]
		if params[:appKey].blank?
			error = "no_key"
		elsif region.nil?
			error = "no_region"
		#elsif Rails.cache.read("map/pop/#{region}", :raw => true, :expires_in => 23.hours)
			#error = "limit_set"
		end	

		if error
			respond_to do |wants|
				wants.json { render :json => {:error => error} }
				wants.xml { render :xml => {:error => error} }
			end
			return
		end
				
		map_list = {}
		Map.all(:select => "id, name", :conditions => ["is_blizzard = ? AND region = ?", false, region]).each do |map|
			map_list[map.id.to_i] = {:days => {}, :name => map.name}
		end

		Map.all(:select => "maps.id as map_id, match_totals.stat_date, match_totals.total_games", :conditions => ["maps.region = ? AND match_totals.stat_date > ? AND maps.is_blizzard = ?", region, 2.days.ago.midnight, false], :joins => "LEFT JOIN match_totals ON match_totals.map_id = maps.id").each do |map|
			map_list[map.map_id.to_i][:days][Time.parse(map.stat_date).strftime("%Y-%m-%d")] = map.total_games.to_i
		end
		
		#Rails.cache.write("map/pop/#{region}", "1", :raw => true, :expires_in => 23.hours)

		respond_to do |wants|
			wants.json { render :json => map_list }
			wants.xml { render :xml => map_list }
		end
	end
	
	# CUSTOM DIVISION LIST
	def custom_div_list
		if params[:appKey].blank? || ( params[:id].to_i != 1 && ( params[:appKey] == "sc2ranks.com" || params[:appKey] == "example.com" ) )
			respond_to do |wants|
				wants.json { render :json => {:error => "no_key"} }
				wants.xml { render :xml => {:error => "no_key"} }
			end
			return
		end			
		
		custom_id = params[:id].to_i
		league = params[:league] == "all" ? nil : LEAGUES[params[:league]] || LEAGUES["grandmaster"]
		bracket = params[:bracket].to_i
		is_random = params[:is_random].to_i == 1 ? true : false
		region = params[:region] != "all" ? params[:region] : nil
    expansion = CURRENT_EXPANSION
    if params.has_key?(:expansion)
      expansion = EXPANSIONS[params[:expansion].to_i] ? params[:expansion].to_i : CURRENT_EXPANSION
    end
		
		custom = CustomRanking.first(:conditions => {:id => custom_id})

		custom_characters = []
		if custom
			CustomRankingCharacter.all(:conditions => {:custom_ranking_id => custom_id}).each do |relation|
				custom_characters.push(relation.character_id)
			end
		end
	
		if custom.nil?
			data = {:error => "no_custom"}
		elsif custom_characters.length == 0
			data = {:error => "no_characters"}
		else
			page_hash = Digest::SHA1.hexdigest("ranks/custom/api/#{custom.cache_key}/#{bracket}/#{league}/#{is_random}/#{expansion}")
		
			etag = Rails.cache.read("#{page_hash}/etag", :raw => true, :expires_in => 30.minutes) 
			return unless etag.nil? || stale?(:etag => etag)
			
			data = Rails.cache.fetch(page_hash, :expires_in => 710.minutes) do
				query = ["expansion = :expansion AND bracket = :bracket AND is_random = :random AND team_characters.character_id IN(:characters)", {:expansion => expansion, :bracket => bracket, :random => is_random, :characters => custom_characters}]
				if league
					query[0] << " AND league = :league"
					query[1][:league] = league
				end
				query[0] << " AND season = :season"
				query[1][:season] = current_season		
	
				if RAILS_ENV == "production"
					iteration = Team.find_by_sql("SELECT teams.* FROM (SELECT DISTINCT ON(hash_id) teams.* FROM teams LEFT JOIN team_characters ON team_characters.team_id=teams.id WHERE ( #{ActiveRecord::Base.send("sanitize_sql_for_conditions", query, "teams")} ) ) AS teams")
				else
					iteration = Team.all(:select => "teams.*", :conditions => query, :joins => "LEFT JOIN team_characters ON team_characters.team_id=teams.id", :include => [:division, :team_characters, :characters])
				end
				
				
				list = []
				iteration.each do |team|
					next if team.division_id.nil?
					team_data = {
						:division => team.division.name,
						:division_id => team.division.id,
						:expansion => team.expansion,
						:division_rank => team.division_rank,
						:bracket => team.bracket,
						:is_random => team.is_random,
						:league => LEAGUES[team.division.league],
						:wins => team.wins,
						:losses => team.losses,
						:points => team.points,
						:ratio => "%.2f" % team.win_ratio,
						:members => []
					}
					
					team.team_characters.each do |team_member|
						team_data[:members].push({:tag => team_member.character.tag, :region => team_member.character.region, :name => team_member.character.name, :bnet_id => team_member.character.bnet_id, :character_code => team_member.character.character_code, :fav_race => RACES[team_member.played_race]})
					end
					
					list.push(team_data)
				end
				
				list
			end
		end
		
		if page_hash
			if !data.is_a?(Hash)
				Rails.cache.fetch("#{page_hash}/etag", :raw => true, :expires_in => 30.minutes) { "#{page_hash}/#{Time.now.to_i}" }
			else
				Rails.cache.delete(page_hash)
				Rails.cache.delete("#{page_hash}/etag")
			end
		end
		
		if !params[:jsonp].blank?
			data = "#{params[:jsonp]}(#{data.to_json})"
		end
		
		respond_to do |wants|
			wants.json { render :json => data }
			wants.xml { render :xml => data }
		end
	end
	
	# MANAGE CUSTOM DIVISION
	def manage_custom
		if params[:appKey].blank?
			respond_to do |wants|
				wants.json { render :json => {:error => "no_key"} }
				wants.xml { render :xml => {:error => "no_key"} }
			end
			return
		end			

		custom = CustomRanking.first(:conditions => {:id => params[:id].to_i})
		if custom
			# Check for bans
			if custom.bans.exists?(:ip_address => request.remote_ip)
				data = {:error => "banned"}
			# Check that the type they want is valid
			elsif params[:type] != "add" && params[:type] != "remove"
				data = {:error => "bad_type"}
			# Auth
			elsif custom.password == Digest::SHA1.hexdigest(params[:password] + custom.password_salt) then
				character_ids = []
				data = {:characters => []}
				
				params[:characters].split(",").each do |character|
					match = character.match("([a-zA-Z]+)-(.+)!([0-9]+)")
					if match.nil? || match.length < 3
						data[:characters].push({:error => "bad_format", :char => character})
						next
					end
					
					region = REGIONS.include?(match[1].downcase) && match[1].downcase
					name = CGI::unescape(match[2])
					bnet_id = match[3].to_i
										
					if region && name && bnet_id > 0
						char_data = Character.first(:conditions => {:region => region, :bnet_id => bnet_id})
						if char_data.nil?
							Armory::Queue.character(:region => region, :bnet_id => bnet_id, :name => name, :tag => 15)
							data[:characters].push({:status => "queued", :char => character})
						elsif params[:type] == "add"
							data[:characters].push({:status => "added", :char => character})

							unless CustomRankingCharacter.exists?(["character_id = ? AND custom_ranking_id = ?", char_data.id, custom.id])
								CustomRankingCharacter.create(:character_id => char_data.id, :custom_ranking_id => custom.id)
							end
						elsif params[:type] == "remove"
							data[:characters].push({:status => "removed", :char => character})
							CustomRankingCharacter.delete_all(["character_id = ? AND custom_ranking_id = ?", char_data.id, custom.id])
						end
						
						character_ids.push(char_data.id) if char_data
					else
						data[:characters].push({:error => "bad_format", :char => character})
					end
				end

				if character_ids.length > 0
					CustomRankingLogs.create(:custom_ranking_id => custom.id, :ip_address => request.remote_ip, :character_ids => character_ids.join(","), :action_type => params[:type] == "add" ? LOG_TYPES[:added] : LOG_TYPES[:removed])
				end
				
				custom.touch
			# Failed to auth :(
			else
				data = {:error => "failed_auth"}
			end
		# Failed to find
		else
			data = {:error => "no_custom"}
		end

		if !params[:jsonp].blank?
			data = "#{params[:jsonp]}(#{data.to_json})"
		end
		
		respond_to do |wants|
			wants.json { render :json => data }
			wants.xml { render :xml => data }
		end
	end
	
	# Character search
	def character_search
		if params[:appKey].blank? || ( params[:name] != "shadow" && ( params[:appKey] == "sc2ranks.com" || params[:appKey] == "example.com" ) )
			respond_to do |wants|
				wants.json { render :json => {:error => "no_key"} }
				wants.xml { render :xml => {:error => "no_key"} }
			end
			return
		end			

		region = params[:region].downcase
		offset = params[:offset].to_i
		name = CGI::unescape(params[:name])
		search_type = params[:searchtype] == "exact" && "exact" || params[:searchtype] == "contains" && "contains" || params[:searchtype] == "ends" && "ends" || "starts"
		
		page_hash = Digest::SHA1.hexdigest("api/char/search/#{region}/#{params[:name]}/#{search_type}/#{offset}")
		
		data = Rails.cache.fetch(page_hash, :expires_in => 30.minutes) do
			if search_type == "exact"
				conditions = ["region = ? AND lower_name LIKE ?", region, name.downcase]
			elsif search_type == "contains"
				conditions = ["region = ? AND lower_name LIKE ?", region, "%#{name.downcase}%"]
			elsif search_type == "ends"
				conditions = ["region = ? AND lower_name LIKE ?", region, "%#{name.downcase}"]
			else
				conditions = ["region = ? AND lower_name LIKE ?", region, "#{name.downcase}%"]
			end
			
			total_chars = (Rails.cache.fetch(Digest::SHA1.hexdigest("#{region}/#{name}/#{search_type}/total"), :raw => true, :expires_in => 1.hour) do
				Character.count(:all, :conditions => conditions) || 0
			end).to_i
			
			if total_chars > 0
				search = {:total => total_chars, :characters => []}
				Character.all(:conditions => conditions, :limit => 10, :offset => offset).each do |character|
					search[:characters].push({:name => character.name, :bnet_id => character.bnet_id})
				end
			else
				search = {:error => "no_characters"}
			end
			
			search
		end

		if !params[:jsonp].blank?
			data = "#{params[:jsonp]}(#{data.to_json})"
		end
		
		respond_to do |wants|
			wants.json { render :json => data }
			wants.xml { render :xml => data }
		end
	end
	
	# SINGLE: Base character
	def base_character
		if params[:appKey].blank? || ( params[:name] != "HuK$530" && ( params[:appKey] == "sc2ranks.com" || params[:appKey] == "example.com" ) )
			respond_to do |wants|
				wants.json { render :json => {:error => "no_key"} }
				wants.xml { render :xml => {:error => "no_key"} }
			end
			return
		end			

		name = CGI::unescape(params[:name])
		region = params[:region].downcase
	
		page_hash = Digest::SHA1.hexdigest("api/char/base/#{region}/#{name}".downcase)
	
		etag = Rails.cache.read("#{page_hash}/etag", :raw => true, :expires_in => 30.minutes) 
		return unless etag.nil? || stale?(:etag => etag)

		data = Rails.cache.fetch(page_hash, :expires_in => 30.minutes) do
			id_type, name, name_id = Character.name_split(name)
			if name && name_id && REGIONS.include?(region)
				if id_type == "bnet"
					query = ["region = ? AND bnet_id = ?", region, name_id]
				else
					query = ["region = ? AND lower_name LIKE ? AND character_code = ?", region, name.downcase, name_id]
				end	
				
				# Now pull zee data!
				char = Character.first(:conditions => query)
				if char
					char_json = {:id => char.id, :region => char.region, :name => char.name, :achievement_points => char.achievement_points, :bnet_id => char.bnet_id, :updated_at => char.updated_at}
					char_json[:character_code] = char.character_code unless char.character_code.nil?
					char_json[:portrait] = {:icon_id => char.portrait.icon_id, :column => char.portrait.icon_column, :row => char.portrait.icon_row} if char.portrait_id
				elsif id_type == "bnet" && !name.blank?
					Armory::Queue.character(:region => region, :bnet_id => name_id, :name => name, :tag => 4)
				end
			end
		
			char_json || {:error => "no_character"}
		end
	
		if data[:error].blank? && data["error"].blank?
			Rails.cache.fetch("#{page_hash}/etag", :raw => true, :expires_in => 30.minutes) { "#{page_hash}/#{Time.now.to_i}" }
		else
			Rails.cache.delete(page_hash)
			Rails.cache.delete("#{page_hash}/etag")
		end
	
		if !params[:jsonp].blank?
			data = "#{params[:jsonp]}(#{data.to_json})"
		end
	
		respond_to do |wants|
			wants.json { render :json => data }
			wants.xml { render :xml => data }
		end
	end
	
	# SINGLE: Character team info
	def character
		return render :json => {:error => "key_ban"} if params[:appKey] == "sc2gears.application"
		
		if params[:appKey].blank? || ( params[:name] != "HuK$530" && ( params[:appKey] == "sc2ranks.com" || params[:appKey] == "example.com" ) )
			respond_to do |wants|
				wants.json { render :json => {:error => "no_key"} }
				wants.xml { render :xml => {:error => "no_key"} }
			end
			return
		end			

		name = CGI::unescape(params[:name])
		region = params[:region].downcase
	
		page_hash = Digest::SHA1.hexdigest("api/team/base/#{region}/#{name}".downcase)
	
		etag = Rails.cache.read("#{page_hash}/etag", :raw => true, :expires_in => 30.minutes) 
		return unless etag.nil? || stale?(:etag => etag)

		data = Rails.cache.fetch(page_hash, :expires_in => 30.minutes) do
			id_type, name, name_id = Character.name_split(name)
			if name && name_id && REGIONS.include?(region)
				if id_type == "bnet"
					query = ["region = ? AND bnet_id = ?", region, name_id]
				else
					query = ["region = ? AND name ILIKE ? AND character_code = ?", region, name.upcase, name_id]
				end	
				
				# Now pull zee data!
				char = Character.first(:conditions => query, :include => {:teams => [:division, :rankings]})
				if char
					char_json = {:id => char.id, :region => char.region, :name => char.name, :achievement_points => char.achievement_points, :bnet_id => char.bnet_id, :updated_at => char.updated_at, :teams => [], :tag => char.tag}
					char_json[:character_code] = char.character_code unless char.character_code.nil?
					char_json[:portrait] = {:icon_id => char.portrait.icon_id, :column => char.portrait.icon_column, :row => char.portrait.icon_row} if char.portrait_id
			
					char.team_characters.each do |team_char|
						team = team_char.team
						
						next if team.nil? or team.division_id.nil?
						next unless team && team.division
						team_data = {
							:division => team.division.name,
							:division_rank => team.division_rank,
							:bracket => team.bracket,
							:expansion => team.expansion,
							:is_random => team.is_random,
							:league => LEAGUES[team.division.league],
							:wins => team.wins,
							:world_rank => team.world_rank(true),
							:region_rank => team.region_rank(true),
							:losses => team.losses,
							:points => team.points,
							:fav_race => RACES[team_char.played_race],
							:ratio => "%.2f" % team.win_ratio,
							:updated_at => team.updated_at,
						}
				
						char_json[:teams].push(team_data)
					end
				elsif id_type == "bnet" && !name.blank?
					Armory::Queue.character(:region => region, :bnet_id => name_id, :name => name, :tag => 4)
				end
			end
			
			char_json || {:error => "no_character"}
		end
	
		if data[:error].blank? && data["error"].blank?
			Rails.cache.fetch("#{page_hash}/etag", :raw => true, :expires_in => 30.minutes) { "#{page_hash}/#{Time.now.to_i}" }
		else
			Rails.cache.delete(page_hash)
			Rails.cache.delete("#{page_hash}/etag")
		end
	
		if !params[:jsonp].blank?
			data = "#{params[:jsonp]}(#{data.to_json})"
		end
	
		respond_to do |wants|
			wants.json { render :json => data }
			wants.xml { render :xml => data }
		end
	end	
	
	# SINGLE: Extended team info
	def team_character
		if params[:appKey].blank? || ( params[:name] != "HuK$530" && ( params[:appKey] == "sc2ranks.com" || params[:appKey] == "example.com" ) )
			respond_to do |wants|
				wants.json { render :json => {:error => "no_key"} }
				wants.xml { render :xml => {:error => "no_key"} }
			end
			return
		end			

		name = CGI::unescape(params[:name])
		region = params[:region].downcase
		
		bracket = params[:bracket].to_i > 0 ? params[:bracket].to_i : 1
		is_random = params[:is_random].to_i == 1 ? true : false
		rank_type = params[:rank_type] == "world" && "world" || params[:rank_type] == "region" && "region" || nil

    expansion = CURRENT_EXPANSION
    if params.has_key?(:expansion)
      expansion = EXPANSIONS[params[:expansion].to_i] ? params[:expansion].to_i : CURRENT_EXPANSION
    end

		page_hash = Digest::SHA1.hexdigest("api/char/team/#{region}/#{name}/#{bracket}/#{is_random}/#{rank_type}/#{expansion}".downcase)
		
		etag = Rails.cache.read("#{page_hash}/etag", :raw => true, :expires_in => 30.minutes) 
		return unless etag.nil? || stale?(:etag => etag)
		
		data = Rails.cache.fetch(page_hash, :expires_in => 30.minutes) do
			id_type, name, name_id = Character.name_split(name)
			if name && name_id && REGIONS.include?(region)
				if id_type == "bnet"
					query = ["region = ? AND bnet_id = ?", region, name_id]
				else
					query = ["region = ? AND name ILIKE ? AND character_code = ?", region, name.upcase, name_id]
				end	

				# Now pull zee data!
				char = Character.first(:conditions => query)
				if char
					char_json = {:region => char.region, :name => char.name, :id => char.id, :achievement_points => char.achievement_points, :bnet_id => char.bnet_id, :updated_at => char.updated_at, :teams => [], :tag => char.tag}
					char_json[:character_code] = char.character_code if !char.character_code.nil?
				
					char.teams.all(:conditions => {:expansion => expansion, :bracket => bracket, :is_random => is_random}, :include => [:rankings, :characters, :division, :team_characters]).each do |team|
						next unless team.division

						team_data = {
							:id => team.id,
							:division_id => team.division.id,
							:division => team.division.name,
							:division_rank => team.division_rank,
							:bracket => team.bracket,
							:is_random => team.is_random,
							:league => LEAGUES[team.division.league],
							:world_rank => team.world_rank(true),
							:region_rank => team.region_rank(true),
							:wins => team.wins,
							:losses => team.losses,
							:points => team.points,
							:ratio => "%.2f" % team.win_ratio,
							:updated_at => team.updated_at,
							:expansion => team.expansion
						}
										
						team.team_characters.each do |team_member|
							if team_member.character_id == char.id
								team_data[:fav_race] = RACES[team_member.played_race]
								next
							end
						
							member_data = {:id => team_member.character.id, :name => team_member.character.name, :bnet_id => team_member.character.bnet_id, :fav_race => RACES[team_member.played_race], :tag => team_member.character.tag}
							member_data[:character_code] = team_member.character.character_code unless team_member.character.character_code.nil?

							team_data[:members] ||= []
							team_data[:members].push(member_data)
						end
					
						char_json[:teams].push(team_data)
					end
				elsif id_type == "bnet" && !name.blank?
					Armory::Queue.character(:region => region, :bnet_id => name_id, :name => name, :tag => 4)
				end
			end
			
			char_json || {:error => "no_character"}
		end

		if data[:error].blank? && data["error"].blank?
			Rails.cache.fetch("#{page_hash}/etag", :raw => true, :expires_in => 30.minutes) { "#{page_hash}/#{Time.now.to_i}" }
		else
			Rails.cache.delete(page_hash)
			Rails.cache.delete("#{page_hash}/etag")
		end
	
		if !params[:jsonp].blank?
			data = "#{params[:jsonp]}(#{data.to_json})"
		end
	
		respond_to do |wants|
			wants.json { render :json => data }
			wants.xml { render :xml => data }
		end
	end	
	
	# MULTIPLE: Character base info
	def mass_base_character
		if params[:appKey].blank?
			respond_to do |wants|
				wants.json { render :json => {:error => "no_key"} }
				wants.xml { render :xml => {:error => "no_key"} }
			end
			return
		end
				
		return render :json => { :error => "no_characters" } if params[:characters].nil? || params[:characters].length == 0
		return render :json => { :error => "too_many_characters" } if params[:characters].length > LIMITS[:mass_api]
	
		page_hash = Digest::SHA1.hexdigest("api/mass/char/bases/#{params[:characters].sort.join}".downcase)
	
		etag = Rails.cache.read("#{page_hash}/etag", :raw => true, :expires_in => 30.minutes) 
		return unless etag.nil? || stale?(:etag => etag)
		
		data = Rails.cache.fetch(page_hash, :expires_in => 30.minutes) do
			query = [""]
			char_list = {}
			params[:characters].values.each do |char|
				next unless char[:name] && ( char[:code] || char[:bnet_id] ) && REGIONS.include?(char[:region])
				name = CGI::unescape(char[:name].upcase)

				query[0] << " OR" unless query[0].blank?
				if char[:bnet_id]
					query[0] << " ( region = ? AND bnet_id = ? )"
					query.push(char[:region], char[:bnet_id].to_i)
				else
					query[0] << " ( region = ? AND name ILIKE ? AND character_code = ? )"
					query.push(char[:region], name, char[:code].to_i)
				end
				
				char_list[char[:region] + name + char[:bnet_id]] = {:region => char[:region], :name => name, :bnet_id => char[:bnet_id].to_i, :tag => 30} if char[:bnet_id]
			end
						
			char_json = []
			unless query[0].blank?
				Character.all(:conditions => query).each do |char|
					data = {:id => char.id, :region => char.region, :name => char.name, :achievement_points => char.achievement_points, :bnet_id => char.bnet_id, :updated_at => char.updated_at, :tag => char.tag}
					data[:character_code] = char.character_code unless char.character_code.nil?
					data[:portrait] = {:icon_id => char.portrait.icon_id, :column => char.portrait.icon_column, :row => char.portrait.icon_row} if char.portrait_id
					
					if params[:sum_stats]
						data[:teams] = {}
						char.teams.all.each do |team|
							next if team.division_id.nil?
								
							data[:teams]["#{team.bracket}:#{team.is_random}"] ||= {:wins => 0, :losses => 0, :bracket => team.bracket, :is_random => team.is_random}
							data[:teams]["#{team.bracket}:#{team.is_random}"][:wins] += team.wins
							data[:teams]["#{team.bracket}:#{team.is_random}"][:losses] += team.losses
						end
						
						data[:teams] = data[:teams].values
					end
					
					char_json.push(data)
					char_list.delete("#{char.region}#{char.name}#{char.bnet_id}")
				end
				
				# Queue what we don't have data for yet
				char_list.values.each do |data|
					Armory::Queue.character(data)
				end
			end
		
			char_json
		end
	
		Rails.cache.fetch("#{page_hash}/etag", :raw => true, :expires_in => 30.minutes) { "#{page_hash}/#{Time.now.to_i}" }
		if !params[:jsonp].blank?
			data = "#{params[:jsonp]}(#{data.to_json})"
		end
		
		render :json => data
	end
	
	# MASS: Character team info
	def mass_character
		if params[:appKey].blank?
			respond_to do |wants|
				wants.json { render :json => { :error => "no_key" } }
				wants.xml { render :xml => { :error => "no_key" } }
			end
			return
		end			
	
		return render :json => { :error => "no_characters" } if params[:characters].nil? || params[:characters].length == 0
		return render :json => { :error => "too_many_characters" } if params[:characters].length > LIMITS[:mass_api]
		return render :json => { :error => "no_team_filter" } if params[:team].nil?

    expansion = CURRENT_EXPANSION
    if params.has_key?(:expansion)
      expansion = EXPANSIONS[params[:expansion].to_i] ? params[:expansion].to_i : CURRENT_EXPANSION
    end
                	
		page_hash = Digest::SHA1.hexdigest("api/mass/teams/base/#{params[:team][:bracket]}/#{params[:team][:is_random]}/#{params[:characters].sort.join}/#{expansion}".downcase)
	
		etag = Rails.cache.read("#{page_hash}/etag", :raw => true, :expires_in => 30.minutes) 
		return unless etag.nil? || stale?(:etag => etag)
		
		data = Rails.cache.fetch(page_hash, :expires_in => 30.minutes) do
			query = [""]
			char_list = {}
			params[:characters].values.each do |char|
				next unless ( char[:name] && char[:code] || char[:bnet_id] ) && REGIONS.include?(char[:region])
				name = char[:name] && CGI::unescape(char[:name].upcase)

				query[0] << " OR" unless query[0].blank?
				if char[:bnet_id]
					query[0] << " ( region = ? AND bnet_id = ? )"
					query.push(char[:region], char[:bnet_id].to_i)
				else
					query[0] << " ( region = ? AND name ILIKE ? AND character_code = ? )"
					query.push(char[:region], name, char[:code].to_i)
				end
				
				char_list[char[:region] + name + char[:bnet_id]] = {:region => char[:region], :name => name, :bnet_id => char[:bnet_id].to_i, :tag => 30} if char[:bnet_id] && name
			end
			
			char_json = []
			unless query[0].blank?
				Character.all(:conditions => query).each do |char|
					data = {:id => char.id, :region => char.region, :name => char.name, :tag => char.tag, :achievement_points => char.achievement_points, :bnet_id => char.bnet_id, :updated_at => char.updated_at, :teams => []}
					data[:character_code] = char.character_code unless char.character_code.nil?
					data[:portrait] = {:icon_id => char.portrait.icon_id, :column => char.portrait.icon_column, :row => char.portrait.icon_row} if char.portrait_id
			
					conditions = ["teams.expansion = ? AND teams.bracket = ? AND teams.division_id IS NOT NULL AND teams.season = ?", expansion, params[:team][:bracket].to_i, current_season]
					if params[:team][:is_random]
						conditions[0] << " AND is_random = ?"
						conditions.push(params[:team][:is_random].to_i == 1 ? true : false)
					end
	
					char.teams.all(:conditions => conditions).each do |team|
						next if team.division.nil? or team.division_id.nil?
						relation = team.team_characters.first(:conditions => {:character_id => char.id})
						data[:teams].push({
							:id => team.id,
							:division => team.division.name,
							:expansion => team.expansion,
							:division_rank => team.division_rank,
							:bracket => team.bracket,
							:is_random => team.is_random,
							:league => LEAGUES[team.division.league],
							:world_rank => team.world_rank(true),
							:region_rank => team.region_rank(true),
							:wins => team.wins,
							:losses => team.losses,
							:points => team.points,
							:fav_race => RACES[relation.played_race],
							:updated_at => team.updated_at,
							:ratio => "%.2f" % team.win_ratio})
					end
					
					char_json.push(data)
					char_list.delete("#{char.region}#{char.name}#{char.bnet_id}")
				end
				
				# Queue what we don't have data for yet
				char_list.values.each do |data|
					Armory::Queue.character(data)
				end
			end
			
			char_json
		end
	
		Rails.cache.fetch("#{page_hash}/etag", :raw => true, :expires_in => 30.minutes) { "#{page_hash}/#{Time.now.to_i}" }

		if !params[:jsonp].blank?
			data = "#{params[:jsonp]}(#{data.to_json})"
		end
		
		render :json => data
	end

private
def current_season
                season = Rails.cache.fetch("seasoncur/all", :expires_in => 30.minutes, :raw => true) do
                        season = nil
                        RANK_REGIONS.each_value do |region|
                                region_season = Rails.cache.read("seasoncur/#{region}", :raw => true).to_i
                                next unless region_season > 0
                                if !season or season < region_season
                                        season = region_season
                                end
                        end

                        season
                end.to_i
                season = 9 unless season > 0
                season
end
end

