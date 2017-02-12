require "cgi"
require "nokogiri"

class CharacterController < ApplicationController
	def rename_character
		name = CGI::unescape(params[:name]).strip
		if name.blank? || name.length <= 2 || params[:name].match(/ /)
			return render :json => {:error => "bad_name"}
		end
		name.gsub!("/", "")
		name.gsub!("\\", "")	
		character = Character.first(:conditions => {:id => params[:character_id].to_i})
		if character.nil?
			return render :json => {:error => "no_character"}
		elsif character.name == name
			return render :json => {:error => "no_rename"}
		end
		
		begin
			method, url_args = Jobs::Profile.get_url({:region => character.region, :bnet_id => character.bnet_id, :name => name})
			response, url = Armory::Node.pull_custom_data(character.region, url_args)
				
			Jobs::Profile.save_character(character, Nokogiri::HTML(response), response)
			return render :json => {:success => true}

		rescue OpenURI::HTTPError => e
			return render :json => {:error => "http", :code => e.message, :message => "Unknown"}
		rescue Exception => e
			return render :json => {:error => "invalid"}
		end

		return render :json => {:error => "retry"}
	end
	
	def reformat_old_url
		redirect_to character_path(params[:region], params[:bnet_id], params[:name])
	end
	
	def character_code
		name = CGI::unescape(params[:name])
		character = Character.first(:conditions => ["region = ? AND UPPER(name) = ? AND character_code = ?", params[:region], name.upcase, params[:code].to_i])
		
		unless character
			flash[:error] = "Sorry, cannot find anyone with from #{REGION_NAMES[params[:region]]} as #{name}##{params[:code]}"
			redirect_to root_path
			return
		end
		
		redirect_to character_path(character.region, character.bnet_id, character.name)
	end
	
	def reformat
		url = params[:character] && params[:character][:url]
		if url.blank?
			flash[:tab_type] = "character"
			flash[:error] = "No URL entered."
			flash[:bad_url] = params[:character][:url]
			redirect_to root_path
			return
		end
		
		match = url.match(/sc2\/.+\/profile\/([0-9]+)\/([0-9]+)\/(.+)/i)
		region = url.match(/(us|kr|tw|sea|eu)\.battle\.net/i)
		region = ["", "cn"] if url.match(/battlenet\.com\.cn/) 
	
		unless match && region
			flash[:tab_type] = "character"
			flash[:error] = "Invalid URL entered, make sure you pass the full URL including the [region].battle.net portion."
			flash[:bad_url] = params[:character][:url]
			redirect_to root_path
			return
		end
		
		region = region[1]
		bnet_id = match[1].to_i
		locale_id = match[2].to_i
		character = match[3]
		character.gsub!(/\/ladde(.+)/, "")
		character.gsub!(/\/achie(.+)/, "")
		character.gsub!("/", "")
		character.gsub!(/#(.+)/, "")
		character.gsub!("\\", "")
		
		# Switch regions if necessary, if it's a sub region
		region = SWITCH_REGIONS[match[2] + region] || region
		
		unless region && REGIONS.include?(region.downcase)
			flash[:tab_type] = "character"
			flash[:error] = "Unknown region \"#{region.to_s}\" found."
			flash[:bad_url] = params[:character][:url]
			redirect_to root_path
			return
		end

		unless bnet_id != 0 && character && region
			flash[:tab_type] = "character"
			flash[:error] = "Invalid battle.net url, you can find it by going to #{link_to "battle.net", "http://battle.net/sc2"} and logging in."
			flash[:bad_url] = params[:character][:url]
			redirect_to root_path
			return
		end
		
		Armory::Queue.character(:region => region, :bnet_id => bnet_id, :name => character, :tag => 6, :force => true)
		redirect_to character_path(region, bnet_id, CGI::unescape(character))
	end
	
	def refresh
		flash[:message] = "Character is being refreshed, this may take a minute or two."
		
		Armory::Queue.character(:region => params[:region].downcase, :bnet_id => params[:bnet_id], :name => params[:name], :force => true, :tag => 5, :priority => 15)
		Armory::Queue.achievement(:region => params[:region].downcase, :bnet_id => params[:bnet_id], :name => params[:name], :force => true, :tag => 5, :priority => 8)
		
		character = Character.first(:conditions => {:region => params[:region], :bnet_id => params[:bnet_id]})
		if character
			Rails.cache.delete("achievements/header/#{character.cache_key}")
			Rails.cache.delete("teams/#{character.cache_key}")
		end

		if params[:previous] == "achievements"
			redirect_to character_achievements_path(params[:region], params[:bnet_id], params[:name])
		else
			redirect_to character_path(params[:region], params[:bnet_id], params[:name])
		end
	end
	
	def vods
		params[:region] = params[:region].downcase
		params[:name] = CGI::unescape(params[:name])
		params[:bnet_id] = params[:bnet_id].to_i
		@offset = params[:offset].to_i
		unless REGIONS.include?(params[:region]) && params[:bnet_id] > 0
			flash[:tab_type] = "character"
			flash[:error] = "Bad URL given, either the region is invalid or you gave an invalid battle.net id."
			return redirect_to root_path
		end
		
		@character = Character.first(:conditions => {:region => params[:region], :bnet_id => params[:bnet_id]}, :include => :achieve_rankings)
		if @character.nil?
			flash[:error] = "Cannot find character."
			return redirect_to root_path
		end
		
		@total_vods = (Rails.cache.fetch("character/vods/totals/#{@character.cache_key}", :raw => true, :expires_in => 3.hours) do
			Vod.count(:conditions => ["player_one_id = ? OR player_two_id = ?", @character.id, @character.id])
		end).to_i
		
		unless read_fragment("character/vods/#{@character.cache_key}/#{@offset}", :raw => true, :expires_in => 12.hours)
			@vod_list = Vod.all(:conditions => ["player_one_id = ? OR player_two_id = ?", @character.id, @character.id], :include => [:player_one_char, :player_two_char], :limit => PAGINATION[:default], :offset => @offset)
		end
	end
	
	def replays
		params[:region] = params[:region].downcase
		params[:name] = CGI::unescape(params[:name])
		params[:bnet_id] = params[:bnet_id].to_i
		@offset = params[:offset].to_i
		unless REGIONS.include?(params[:region]) && params[:bnet_id] > 0
			flash[:tab_type] = "character"
			flash[:error] = "Bad URL given, either the region is invalid or you gave an invalid battle.net id."
			return redirect_to root_path
		end
		
		@character = Character.first(:conditions => {:region => params[:region], :bnet_id => params[:bnet_id]}, :include => :achieve_rankings)
		if @character.nil?
			flash[:error] = "Cannot find character."
			return redirect_to root_path
		end
		
		@total_replays = (Rails.cache.fetch("character/replays/totals/#{@character.cache_key}", :raw => true, :expires_in => 3.hours) do
			@character.replays.count
		end).to_i
		
		unless read_fragment("character/replays/#{@character.cache_key}/#{@offset}", :raw => true, :expires_in => 12.hours)
			@replay_list = @character.replays.all(:offset => @offset, :limit => PAGINATION[:default], :include => [:map, :replay_characters, :characters], :order => "played_on DESC")
		end
	end
		
	def map_stats
		params[:region] = params[:region].downcase
		params[:name] = CGI::unescape(params[:name])
		params[:bnet_id] = params[:bnet_id].to_i
		params[:map_id] = params[:map_id].to_i

		unless REGIONS.include?(params[:region]) && params[:bnet_id] > 0
			flash[:tab_type] = "character"
			flash[:error] = "Bad URL given, either the region is invalid or you gave an invalid battle.net id."
			return redirect_to root_path
		end
		
		@character = Character.first(:conditions => {:region => params[:region], :bnet_id => params[:bnet_id]}, :include => :achieve_rankings)
		if @character.nil?
			flash[:error] = "Cannot find character."
			return redirect_to root_path
		end
		
		@map = Map.first(:conditions => {:id => params[:map_id]})
		if @map.nil?
			flash[:error] = "No map id found"
			return redirect_to root_path
		end

		unless read_fragment("character/map/#{@character.cache_key}/#{params[:map_id]}", :raw => true, :expires_in => 12.hours)
			@match_list = @character.matches.all(:conditions => ["map_id = ?", @map.id], :order => "played_on DESC, id DESC", :limit => 25, :include => :map)
			
			@map_summary = {}
			@character.matches.all(:select => "bracket, results, SUM(points) as total_points, COUNT(*) as total", :conditions => {:map_id => @map.id}, :group => "bracket, results").each do |stats|
				stats.bracket = stats.bracket.to_i
				stats.results = stats.results.to_i
				
				@map_summary[stats.bracket] ||= {:total => 0, :points => 0, :results => {}}
				@map_summary[stats.bracket][:results][stats.results] = {:total => stats.total.to_i, :points => stats.total_points.to_i}
				
				@map_summary[stats.bracket][:points] += stats.total_points.to_i
				@map_summary[stats.bracket][:total] += stats.total.to_i
			end
		end
	end
	
	def maps
		params[:region] = params[:region].downcase
		params[:name] = CGI::unescape(params[:name])
		params[:bnet_id] = params[:bnet_id].to_i
		@offset = params[:offset].to_i
		unless REGIONS.include?(params[:region]) && params[:bnet_id] > 0
			flash[:tab_type] = "character"
			flash[:error] = "Bad URL given, either the region is invalid or you gave an invalid battle.net id."
			return redirect_to root_path
		end
		
		@character = Character.first(:conditions => {:region => params[:region], :bnet_id => params[:bnet_id]}, :include => :achieve_rankings)
		if @character.nil?
			flash[:error] = "Cannot find character."
			return redirect_to root_path
		end
		
		@total_maps = (Rails.cache.fetch("character/map/totals/#{@character.cache_key}", :raw => true, :expires_in => 12.hours) do
			@character.matches.all(:select => "COUNT(DISTINCT(map_id)) as total").first.total
		end).to_i
		
		unless read_fragment("character/maps/#{@character.cache_key}/#{@offset}", :raw => true, :expires_in => 12.hours)
			@map_list = @character.matches.all(:from => "(SELECT DISTINCT ON(map_id) * FROM match_histories WHERE match_histories.character_id = #{@character.id}) AS match_histories", :offset => @offset, :limit => PAGINATION[:default], :include => :map, :order => "played_on DESC")

			map_ids = []
			@map_list.each do |map|
				map_ids.push(map.map_id)
			end
			
			@map_totals = {}
			@character.matches.all(:select => "COUNT(*) as total, results, map_id", :conditions => ["map_id IN (?)", map_ids], :group => "map_id, results").each do |stats|
				stats.map_id = stats.map_id.to_i
				stats.total = stats.total.to_i
				
				@map_totals[stats.map_id] ||= {:total => 0}
				@map_totals[stats.map_id][stats.results.to_i] = stats.total
				@map_totals[stats.map_id][:total] += stats.total
			end
		end
	end
	
	def achievements
		params[:region] = params[:region].downcase
		params[:name] = CGI::unescape(params[:name])
		params[:bnet_id] = params[:bnet_id].to_i
		@category_id = params[:category_id].to_i > 0 ? params[:category_id].to_i : ACHIEVEMENT_DEFAULT
		unless REGIONS.include?(params[:region]) && params[:bnet_id] > 0
			flash[:tab_type] = "character"
			flash[:error] = "Bad URL given, either the region is invalid or you gave an invalid battle.net id."
			return redirect_to root_path
		end
		
		@character = Character.first(:conditions => {:region => params[:region], :bnet_id => params[:bnet_id]}, :include => :achieve_rankings)
		# No character found
		if @character.nil?
			flash[:error] = "Cannot find character."
			return redirect_to root_path
		end
		
		unless read_fragment("achievements/#{@category_id}/#{@character.cache_key}", :raw => true, :expires_in => 12.hours)
			@achievements_earned = @character.achievements.all(:conditions => ["achievements.category_id = ? AND achievements.is_parent = ? AND character_achievements.earned_on IS NOT ?", @category_id, false, nil], :joins => "LEFT JOIN achievements ON achievements.achievement_id=character_achievements.achievement_id", :order => "earned_on DESC, name DESC", :include => :data)
		end
	end
	
	def season
		params[:season] = params[:season].to_i
		params[:region] = params[:region].downcase
		params[:name] = CGI::unescape(params[:name])
		params[:bnet_id] = params[:bnet_id].to_i
		unless REGIONS.include?(params[:region]) && params[:bnet_id] > 0
			flash[:tab_type] = "character"
			flash[:error] = "Bad URL given, either the region is invalid or you gave an invalid battle.net id."
			return redirect_to root_path
		end
		
		@character = Character.first(:conditions => {:region => params[:region], :bnet_id => params[:bnet_id]}, :include => :achieve_rankings)
		# No character found
		if @character.nil?
			flash[:error] = "Cannot find character."
			return redirect_to root_path
		end

		unless read_fragment("season/#{params[:season]}/#{@character.id}", :raw => true, :expires_in => 12.hours)
			team_ids = []
			@character.all_teams.all(:select => "teams.id").each do |team|
				team_ids.push(team.id)
			end
			
			@active_ids = {}
			@character.teams.all(:select => "teams.id", :conditions => ["season = ?", @character.season]).each do |team|
				@active_ids[team.id] = true
			end
						
			if params[:season] <= 4
				@teams = TeamsFromPatch.send("p#{params[:season] == 1 && 120 || params[:season] == 2 && 130 || params[:season] == 3 && 135 || params[:season] == 4 && 141 || params[:season]}").all(:conditions => ["id IN(?)", team_ids], :order => "bracket ASC")
			else
				@teams = TeamSeason.all(:conditions => ["season = ? AND (id IN(?) OR team_id IN(?))", params[:season], team_ids, team_ids], :order => "bracket ASC")
			end

			if @teams.length == 0
				@character.seasons_skipped = @character.seasons_skipped.to_s.split(",").push(params[:season].to_s).uniq.join(",")
				@character.seasons_skipped = params[:season].to_s if @character.seasons_skipped.to_s.length > 250
				@character.touch
				flash[:error] = "Doesn't look like this player has any teams from Season #{params[:season]}."
				return redirect_to character_path(@character.region, @character.bnet_id, @character.name)
			end
		end
	end
	
	def index
		params[:region] = params[:region].downcase
		params[:name] = CGI::unescape(params[:name])
		params[:bnet_id] = params[:bnet_id].to_i
		unless REGIONS.include?(params[:region]) && params[:bnet_id] > 0
			flash[:tab_type] = "character"
			flash[:error] = "Bad URL given, either the region is invalid or you gave an invalid battle.net id."
			return redirect_to root_path
		end
		
		@character = Character.first(:conditions => {:region => params[:region], :bnet_id => params[:bnet_id]}, :include => :achieve_rankings)
		if @character.nil?
			# Check for errors first
			@error = Armory::Error.first(:conditions => {:region => params[:region], :bnet_id => params[:bnet_id], :class_name => "Jobs::Profile"})
			if @error && @character.nil?
				render :action => :error
				return
			end
			
			# Otherwise queue it
			Armory::Queue.character(:region => params[:region], :bnet_id => params[:bnet_id], :name => params[:name], :tag => 6)
			
			@position = Armory::Job.queue_position({:class_name => "Jobs::Profile", :bnet_id => params[:bnet_id], :region => params[:region]}) || 0
			if @position == 0
				flash[:error] = "Failed to queue this character, please report this."
				redirect_to root_path
				return
			end
			
			@eta = (@position * 1.7) + (@position == 1 ? 5 : 0)
			render :action => :queued
			return
		elsif @character.updated_at <= 1.week.ago
			Armory::Queue.character(:region => params[:region], :bnet_id => params[:bnet_id], :name => params[:name], :tag => 6, :force => false)
		end
		
		unless read_fragment("teams/stats/#{@character.cache_key}", :raw => true, :expires_in => 30.minutes)
			@replays = @character.replays.all(:order => "played_on DESC", :limit => 10, :include => [:map, :replay_characters, :characters, :site])
		end
	end
end
