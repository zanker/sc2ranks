class RankingsController < ApplicationController
	def masters
	  redirect_to(rank_filter_path(:region => (params[:region] || "all"), :league => "master"))
	end
	
	def gm_log
		@offset = params[:offset].to_i > 0 ? params[:offset].to_i : 0
		@page_hash = Digest::SHA1.hexdigest("gm/changes/#{@region}/#{@offset}")
		
		etag = Rails.cache.read("#{@page_hash}/etag", :raw => true, :expires_in => 2.hours) 
		return unless etag.nil? or stale?(:etag => etag)
		
		unless read_fragment(@page_hash, :raw => true, :expires_in => @cache_time)
			@changes = []
			
			conditions = ["( new_league = ? OR old_league = ? )", LEAGUES["grandmaster"], LEAGUES["grandmaster"]]
			
			DivisionChanges.all(:conditions => conditions, :offset => @offset, :limit => 200, :include => {:team => {:team_characters => :character}}, :order => "created_at DESC").each do |c|
				@changes.push(c)
			end
			
			@total_changes = (Rails.cache.fetch("gm/changes/totals/#{@region}", :expires_in => 2.hours, :raw => true) do
				DivisionChanges.count(:all, :conditions => conditions)
			end).to_i
			
			Rails.cache.write("#{@page_hash}/etag", "#{@page_hash}/#{Time.now.to_i}", :raw => true, :expires_in => @cache_time)
		end
	end
	
	def url_format
		if params[:filter].nil?
			flash[:error] = "Invalid request"
			redirect_to root_path
		else
			redirect_to rank_filter_path(params[:filter][:region], params[:filter][:league], params[:filter][:bracket], params[:filter][:race], params[:filter][:sort], 0, params[:filter][:activity], params[:filter][:expansion])
		end
	end
	
	def search
		name = CGI::unescape(params[:ranksearch][:name])
		region = params[:ranksearch][:region] || params[:region]
		character = Character.first(:conditions => ["region = ? AND UPPER(name) = ? AND character_code = ?", region, name.upcase, params[:ranksearch][:code].to_i])
			
		cookies[:code_region] = region
		unless character
			flash[:error] = "Sorry, cannot find anyone with from #{REGION_NAMES[region]} as #{name}##{params[:ranksearch][:code]}"
			return redirect_to root_path
		end
		
		params[:sort] ||= "points"
		params[:race] ||= "all"
		params[:region] ||= "all"
		params[:league] ||= DEFAULT_LEAGUE
		params[:bracket] ||= 1
		params[:race] ||= "all"
		params[:activity] ||= 0
		params[:expansion] ||= CURRENT_EXPANSION

		# Reset offfset if it's a different character
		params[:team_offset] = 0 if character.id != params[:previous_id].to_i
		
		redirect_to rank_filter_path(params[:region], params[:league], params[:bracket], params[:race], params[:sort], 0, params[:activity], params[:expansion], :character => character.id, :team_offset => params[:team_offset].to_i)
	end
	
	def graph
	end
	
	def index
		character_id = params[:character].to_i
		
		@league = params[:league] == "all" ? nil : LEAGUES[params[:league]] || DEFAULT_LEAGUE
		@bracket = params[:bracket] && params[:bracket].match(/([0-9]+)/)
		@bracket = @bracket && @bracket[1].to_i > 0 ? @bracket[1].to_i : 1
		@is_random = params[:bracket] && params[:bracket].match(/R/) ? true : false
		@offset = params[:offset].to_i > 0 ? params[:offset].to_i : 0
		@region = params[:region] != "all" ? params[:region] : nil
		@expansion = CURRENT_EXPANSION
		if params.has_key?(:expansion)
			@expansion = EXPANSIONS[params[:expansion].to_i] ? params[:expansion].to_i : CURRENT_EXPANSION
		end


		current_season = Rails.cache.fetch("seasoncur/all", :expires_in => 1.hour, :raw => true) do
                	season = nil
			RANK_REGIONS.each_value do |region|
                       		region_season = Rails.cache.read("seasoncur/#{region}", :raw => true).to_i
                        	next unless region_season > 0
				if !season or season < region_season
                        		season = region_season
                		end
                	end

                	unless season
                                char = Character.first(:select => "MAX(season) as season")
                        	season = char && char.season || 9
                	end

			season
		end.to_i
		current_season = 9 unless current_season > 0

                if @league == DEFAULT_LEAGUE
                        force_downgrade = Rails.cache.fetch("season/trans/#{@expansion}", :expires_in => 1.hour, :raw => true) do
                                Team.exists?(["league = ? AND division_id IS NOT NULL AND season = ? AND expansion = ?", DEFAULT_LEAGUE, current_season, @expansion]) ? "1" : "0"
                        end

                        if force_downgrade == "0"
				["master", "diamond", "platinum", "gold"].each do |downgrade|
					force = Rails.cache.fetch("season/trans/#{@expansion}/#{downgrade}", :expires_in => 1.hour, :raw => true) do
						Team.exists?(["league = ? AND division_id IS NOT NULL AND season = ? AND expansion = ?", LEAGUES[downgrade], current_season, @expansion]) ? "1" : "0"
					end				
				
					if force == "1"
						@league = LEAGUES[downgrade]
						params[:league] = downgrade
						break
					end
				end	
			end
                end

	
		if params[:sort] == "pointpool"
			pool_mod = "max_pool"
			unless @is_random
				if @bracket == 2
					pool_mod = "(max_pool * 0.66)"
				elsif @bracket == 3 or @bracket == 4
					pool_mod = "(max_pool * 0.33)"
				end
			end
		end
			
		@sort_by = params[:sort] == "ratio" && "win_ratio" || params[:sort] == "comp" && "race_comp" || params[:sort] == "pointratio" && "(points * win_ratio)" || params[:sort] == "wins" && "wins" || params[:sort] == "losses" && "losses" || params[:sort] == "played" && "(wins + losses)" || params[:sort] == "pointpool" && "(points - #{pool_mod})" || "points"
		@race = params[:race] && RACES[params[:race]] || "all"
		@activity = params[:activity].to_i > 0 ? params[:activity].to_i : nil
                if( @league == DEFAULT_LEAGUE or @league == LEAGUES["master"] )
                        expire_tag = Rails.cache.read("expire/#{@league}", :raw => true)
                else
                        expire_tag = ""
                end
                @page_hash = Digest::SHA1.hexdigest("ranks/#{@bracket}/#{@region.to_s}/#{@offset}/#{@league}/#{@sort_by}/#{@is_random}/#{@race}/#{character_id}/#{params[:team_offset].to_i}/#{@activity}/#{force_downgrade}/#{current_season}/#{expire_tag}/#{@expansion}")

		@cache_time = (@league == DEFAULT_LEAGUE ) ? 20.minutes : 6.hours
					
		return unless !flash[:message].blank? || !flash[:error].blank? || stale?(:etag => @page_hash)
		
		unless read_fragment(@page_hash, :raw => true, :expires_in => @cache_time)
			if @offset == 0
				@stats = Rails.cache.fetch("char/stats", :expires_in => 12.hours) do
					totals = {"total" => 0}
					RANK_REGIONS_LIST.each do |region|
						totals[region] = (Rails.cache.fetch("population/chars/#{region}", :raw => true, :expires_in => 6.hours) do
							Character.count(:conditions => {:rank_region => region})
						end).to_i
						
						totals["total"] += totals[region]
					end
					
					Rails.cache.write("population/chars/global", totals["total"], :raw => true, :expires_in => 6.hours)

					totals
				end
			end
			
			# Build query!
			query = ["bracket = :bracket AND is_random = :random AND teams.division_id IS NOT NULL AND teams.season = :season AND teams.expansion = :expansion", {:bracket => @bracket, :random => @is_random, :season => current_season, :expansion => @expansion}]
			if @region
				query[0] << " AND teams.region = :region"
				query[1][:region] = @region
			end
			
			if @league
				query[0] << " AND league = :league"
				query[1][:league] = @league
			end
			
			if @race != "all"
				if @bracket == 1 || @is_random
					query[0] << " AND race_comp = :race"
					query[1][:race] = @race.to_s
				else
					query[0] << " AND race_comp LIKE :race"
					query[1][:race] = "%#{@race}%"
				end
			end
			
			if @activity
				query[0] << " AND last_game_at >= :activity"
				query[1][:activity] = @activity.days.ago
			end
			
			# figure out includes
			include_assocs = [:division, :team_characters, :characters]
			
			# Need to do a join to find the bonus pool for a region
			joins = nil
			if params[:sort] == "pointpool"
				joins = "LEFT JOIN region_bonus_pools ON (region_bonus_pools.region = teams.region AND region_bonus_pools.expansion = teams.expansion)"
				include_assocs.push(:region_pool)
			end
			
			# We need to find a character
			if character_id > 0 && @sort_by == "race_comp"
				flash[:error] = "You cannot sort by race composition and lookup a find characters page."
			elsif character_id > 0
				@character = Character.first(:conditions => {:id => character_id})
				unless @character
					params.delete(:character)
					params.delete(:team_offset)

					flash[:error] = "No character found for given id."
					return redirect_to url_for(params)
				end
				
				# Figure out what random point magic we are using
				team_offset = params[:team_offset].to_i
				char_team = @character.teams.first(:select => "#{@sort_by} as total", :conditions => query, :joins => joins, :offset => team_offset)
				unless char_team	
					if team_offset > 0
						params[:team_offset] = team_offset - 1
						flash[:error] = "Cannot find a #{(team_offset + 1).ordinal} team for #{@character.name}##{@character.character_code}."
						return redirect_to url_for(params)
					else
						params.delete(:character)
						params.delete(:team_offset)

						flash[:error] = "No team for #{@character.name}#{@character.character_code} found."
						return redirect_to url_for(params)
					end
				end
				
				# Find their rank using all of the fancy searching info we have
				query_find = query[0]
				query[0] += " AND #{@sort_by} > :team_column"
				query[1][:team_column] = char_team.total.to_f
				
				@offset = Team.first(:select => "COUNT(*) as total", :conditions => query, :joins => joins)
				@offset = ((@offset && @offset.total.to_i || 0) / 100.to_f).floor * 100
				
				# Remove our taint
				query[0] = query_find
				query[1].delete(:team_column)
			end

			# No sense in repulling total teams because that won't change
			@total_teams = (Rails.cache.fetch(Digest::SHA1.hexdigest("ranks/lists/#{@bracket}/#{@league}/#{@is_random}/#{@region}/#{@race}/#{@activity}/#{@expansion}"), :raw => true, :expires_in => 3.hours) do
				Team.count(:all, :conditions => query) || 0
			end).to_i
			
			@offset = @offset > @total_teams ? (@total_teams - 100) : @offset
			@offset = @offset < 0 ? 0 : @offset
			
			@rankings = []
		
			Team.all(:conditions => query, :order => "#{@sort_by} DESC", :limit => 100, :offset => @offset, :joins => joins, :include => include_assocs).each do |team|
				next if team.division_id.nil? or team.division.nil?
				@rankings.push(team)
			end
			
		end
	end
end
