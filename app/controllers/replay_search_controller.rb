require "cgi"
class ReplaySearchController < ApplicationController
	def index
		@league = params[:league] == "all" ? nil : LEAGUES[params[:league]] || LEAGUES["grandmaster"]
		@bracket = params[:bracket] && params[:bracket].match(/([0-9]+)/)
		@bracket = @bracket && @bracket[1].to_i > 0 ? @bracket[1].to_i : 1
		@is_random = params[:bracket] && params[:bracket].match(/R/) ? true : false
		@offset = params[:offset].to_i
		@region = params[:region] != "all" ? params[:region] : nil
		@race = params[:race] && RACES[params[:race]] || nil
		#@patch = PATCH_BUILDS[params[:patch].to_i] ? params[:patch].to_i : nil
		@patch = params[:patch].to_i		

		@page_hash = Digest::SHA1.hexdigest("replays/#{@bracket}/#{@region.to_s}/#{@offset}/#{@league}/#{@is_random}/#{@race}/#{@patch}")
		@cache_time = 3.hours
					
		etag = Rails.cache.read("#{@page_hash}/etag", :raw => true, :expires_in => @cache_time) 
		return unless !flash[:message].blank? || !flash[:error].blank? || etag.nil? || stale?(:etag => etag)
		
		unless read_fragment(@page_hash, :raw => true, :expires_in => @cache_time)
			conditions = ["replays.bracket = '?v?' AND teams.is_random = ? AND replay_characters.team_id > 0", @bracket, @bracket, @is_random]
			if @league
				conditions.first << " AND teams.league = ? "
				conditions.push(@league)
			end
			
			if @region
				conditions.first << " AND teams.region = ?"
				conditions.push(@region)
			end
			
			if @patch
				conditions.first << " AND replays.build_version = ?"
				conditions.push(@patch)
			end
			
			if @race
				conditions.first << " AND replays.race_comp LIKE '%?%'"
				conditions.push(@race)
			end
			
			joins = "JOIN replay_characters ON replay_characters.replay_id=replays.id JOIN teams ON teams.id=replay_characters.team_id"
			
			@total_replays = (Rails.cache.fetch(Digest::SHA1.hexdigest("replay/#{@bracket}/#{@region.to_s}/#{@league}/#{@is_random}/#{@race}/#{@patch}"), :raw => true, :expires_in => 4.hours) do
				Replay.all(:select => "COUNT(DISTINCT(replays.id)) as total", :conditions => conditions, :joins => joins).first.total || 0
			end).to_i

			@replays = Replay.all(:select => "DISTINCT(replays.id), replays.*", :conditions => conditions, :joins => joins, :order => "played_on DESC", :limit => PAGINATION[:default], :offset => @offset, :include => [:characters, :map, :site])
		end
	end

	def reformat
		if params[:filter].nil?
			flash[:error] = "Invalid search"
			flash[:tab_type] = "replay_search"
			redirect_to root_path
		end
		
		redirect_to replay_search_path(params[:filter])
	end
end
