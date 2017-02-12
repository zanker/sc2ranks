class DivisionsController < ApplicationController
	def url_format
		if params[:filter].nil?
			flash[:tab_type] = "divisions"
			flash[:error] = "Invalid request."
			redirect_to root_path
		else
			redirect_to rank_filter_divisions_path(params[:filter][:region], params[:filter][:league], params[:filter][:bracket], params[:filter][:sort], 0)
		end
	end

	def bnet_url
		division_id = params[:division_id].to_i
		internal_div_id = (Rails.cache.fetch("division/redirect/#{division_id}", :expires_in => 24.hours) do
			division = Division.first(:conditions => {:bnet_id => division_id})
			division && division.id || -1
		end).to_i
		
		if internal_div_id == -1
			flash[:error] = "Cannot find division id ##{division_id}."
			redirect_to root_path
			return
		end
		
		redirect_to rank_division_path(internal_div_id)
	end
	
	def player_rankings
		division_id = params[:division_id].to_i
		@page_hash = "division/players/#{division_id}"
		
		@division = Rails.cache.fetch("division/cache/#{division_id}", :expires_in => 1.hour) do
			division = Division.first(:conditions => {:id => division_id})
			division.attributes if division
		end
		
		unless @division
			flash[:error] = "Cannot find division id ##{division_id}."
			redirect_to root_path
			return
		end
		
		etag = Rails.cache.read("#{@page_hash}/etag", :raw => true, :expires_in => 10.minutes) 
		return unless etag.nil? || stale?(:etag => etag)

		unless read_fragment(@page_hash, :raw => true, :expires_in => 10.minutes)
			Rails.cache.write("#{@page_hash}/etag", "#{@page_hash}/#{Time.now.to_i}", :raw => true, :expires_in => 10.minutes)

			@rankings = []
			Team.all(:conditions => {:division_id => division_id}, :order => "points DESC", :include => [:division, :characters]).each do |team|
				@rankings.push(team)
			end
		end
	end
		
	def divisions_by_name
		@name = CGI::unescape(params[:name] || "")
		@league = params[:league] && LEAGUES[params[:league]] || LEAGUES["master"]
		@region = params[:region] != "all" ? params[:region] : nil
		@sort_by = params[:sort] == "ratio" && "average_wins" || params[:sort] == "games" && "average_games" || params[:sort] == "players" && "total_teams" || params[:sort] == "pointratio" && "(average_points * average_wins)"|| "average_points"

		@page_hash = Digest::SHA1.hexdigest("ranks/divisions/#{@name}/#{@league}/#{@region}/#{@sort_by}")
	
		etag = Rails.cache.read("#{@page_hash}/etag", :raw => true, :expires_in => 30.minutes) 
		return unless !flash[:message].blank? || !flash[:error].blank? || etag.nil? || stale?(:etag => etag)

		unless read_fragment(@page_hash, :raw => true, :expires_in => 30.minutes)
			Rails.cache.write("#{@page_hash}/etag", "#{@page_hash}/#{Time.now.to_i}", :raw => true, :expires_in => 30.minutes)
			
			query = ["region = :region AND LOWER(name) = LOWER(:name)", {:region => @region, :name => @name}]
						
			@divisions = []
			Division.all(:conditions => query, :order => "#{@sort_by} DESC").each do |division|
				stat = Team.first(:select => "MAX(joined_league) as last_joined, MIN(joined_league) as first_joined", :conditions => {:division_id => division.id})
				if stat
					puts stat.to_json
					division[:first_joined] = Time.parse(stat["first_joined"]) if stat["first_joined"]
					division[:last_joined] = Time.parse(stat["last_joined"]) if stat["last_joined"]
				end
				
				@divisions.push(division)
			end
		end
	end
	
	def index
		@league = params[:league] && LEAGUES[params[:league]] || LEAGUES["master"]
		@bracket = params[:bracket] && params[:bracket].match(/([0-9]+)/)
		@bracket = @bracket && @bracket[1].to_i > 0 ? @bracket[1].to_i : 1
		@is_random = params[:bracket] && params[:bracket].match(/R/) ? true : false
		@offset = params[:offset].to_i
		@region = params[:region] != "all" ? params[:region] : nil
		@sort_by = params[:sort] == "ratio" && "average_wins" || params[:sort] == "games" && "average_games" || params[:sort] == "players" && "total_teams" || params[:sort] == "pointratio" && "(average_points * average_wins)"|| "average_points"
		@page_hash = Digest::SHA1.hexdigest("ranks/divisions/#{@bracket}/#{@region}/#{@offset}/#{@league}/#{@sort_by}/#{@is_random}/#{@race}")
		
		if params[:force_clear]
			Rails.cache.delete("#{@page_hash}/etag")
			Rails.cache.delete("#{@page_hash}")
			Rails.cache.delete("views/#{@page_hash}")
		end

		etag = Rails.cache.read("#{@page_hash}/etag", :raw => true, :expires_in => 10.minutes) 
		return unless !flash[:message].blank? || !flash[:error].blank? || etag.nil? || stale?(:etag => etag)

		unless read_fragment(@page_hash, :raw => true, :expires_in => 10.minutes)
			Rails.cache.write("#{@page_hash}/etag", "#{@page_hash}/#{Time.now.to_i}", :raw => true, :expires_in => 10.minutes)
		
			if !@region
        			current_season = Rails.cache.fetch("seasoncur/all", :expires_in => 30.minutes, :raw => true) do
     	  	 	                season = nil
     		   	                RANK_REGIONS.each_value do |region|
	        	                        region_season = Rails.cache.read("seasoncur/#{region}", :raw => true)
        		                        if !season or season < region_season
     		   	                                season = region_season
        		                        end
        	 	               end

        	        	        unless season
        	                	        char = Character.first(:select => "MAX(season) as season")
        	                	        season = char && char.season || 8
        	                	end
		
	                       		season
		                end
			else
				current_season = Rails.cache.fetch("seasoncur/#{@region}", :expires_in => 1.day, :raw => true) do
					char = Character.first(:select => "MAX(season) AS season", :conditions => {:region => RANK_REGIONS_GROUP[@region]})
					char && char.season || 8
				end
			end

			if @region.nil? && @league == DEFAULT_LEAGUE && @bracket == 1 && !@is_random && @offset == 0
				@stats = Rails.cache.fetch("divisions/stats", :expires_in => 6.hours) do
					totals = {"total" => 0}
					Division.all(:select => "COUNT(*) as total, region", :conditions => ["season = ?", current_season.to_i], :group => "region").each do |stats|
						totals[stats.region] ||= 0
						totals[stats.region] += stats.total.to_i
						totals["total"] += stats.total.to_i
					end

					totals
				end
			end
	
			# Build query!
			query = ["bracket = :bracket AND league = :league AND is_random = :random AND season = :season", {:bracket => @bracket, :season => current_season.to_i, :league => @league, :random => @is_random}]
			if @region
				query[0] += " AND region = :region"
				query[1][:region] = @region
			end
	
			# No sense in repulling total teams because that won't change
			@total_divs = (Rails.cache.fetch(Digest::SHA1.hexdigest("divisions/#{query.to_s}"), :raw => true, :expires_in => 10.minutes) do
				Division.count(:all, :conditions => query) || 0
			end).to_i
		
			@offset = @offset > @total_divs ? (@total_divs - 100) : @offset
			@offset = @offset < 0 ? 0 : @offset
	
			@rankings = []
			placement = @offset
			previous_points = nil
			
			Division.all(:conditions => query, :order => "#{@sort_by} DESC", :limit => 100, :offset => @offset).each do |division|
				placement += 1 if previous_points.nil? || previous_points != division.average_points
				division[:row_num] = placement - @offset
				division[:rank] = placement
				
				@rankings.push(division)
			end
		end
	end
end
