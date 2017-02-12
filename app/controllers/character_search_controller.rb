require "cgi"
class CharacterSearchController < ApplicationController
	def index
		@region = params[:region].downcase
		@offset = params[:offset] ? params[:offset].to_i : 0
		@exact = params[:action] == "index" ? false : true
		@name = CGI::unescape(params[:name].strip)
		@search_type = params[:type] == "exact" && "exact" || params[:type] == "contains" && "contains" || params[:type] == "ends" && "ends" || "starts"
		@league = LEAGUES.include?(params[:league].to_i) ? params[:league].to_i : nil
		@page_hash = Digest::SHA1.hexdigest("search/#{@search_type}/#{@region}/#{@name}/#{@search_type}/#{@offset}")
			
		etag = Rails.cache.read("#{@page_hash}/etag", :raw => true, :expires_in => 30.minutes) 
		return unless etag.nil? || stale?(:etag => etag)
		
		unless read_fragment(@page_hash, :raw => true, :expires_in => 30.minutes)
			conditions = params[:type] == "exact" ? ["lower_name = :name", {}] : ["lower_name LIKE :name", {}]
			
			if params[:type] == "contains"
				conditions[1][:name] = "%#{@name.downcase}%"
			elsif params[:type] == "ends"
				conditions[1][:name] = "%#{@name.downcase}"
			elsif params[:type] == "exact"
				conditions[1][:name] = @name.downcase
			else
				conditions[1][:name] = "#{@name.downcase}%"
			end
			
			if @region != "all"
				conditions[0] << " AND rank_region = :region"
				conditions[1][:region] = @region
			end
						
			@total_chars = (Rails.cache.fetch(Digest::SHA1.hexdigest("#{@region}/#{@name}/#{@exact}/#{@league}/#{@search_type}/total"), :raw => true, :expires_in => 30.minutes) do
				Character.count(:all, :conditions => conditions) || 0
			end).to_i
						
			# Only one result, just shunt them to the profile page
			if @total_chars == 1
				character = Character.first(:conditions => conditions)
				if character
					redirect_to character_path(character.region, character.bnet_id, character.name)
					return
				end
			end
			
			Rails.cache.write("#{@page_hash}/etag", "#{@page_hash}/#{Time.now.to_i}", :raw => true, :expires_in => 30.minutes)

			@char_list = []
			Character.all(:conditions => conditions, :include => {:teams => :division}, :limit => 100, :offset => @offset).each do |character|
				team = nil
				character.teams.each do |team_data|
					next if team_data.nil? or team_data.division_id.nil? or team_data.division.nil?
					team = team_data if team_data && ( team.nil? || team.points < team_data.points || team.league < team_data.league )
				end
				
				next if team.nil?
				
				character[:team] = team
				@char_list.push(character)
			end
		end

		render :action => :index
	end
	
	def character_code
		if params[:search].nil? || params[:search][:name].nil?
			flash[:error] = "Invalid request"
			redirect_to root_path
			return
		end
		
		cookies[:code_region] = params[:search][:region]
		params[:search][:name] = CGI::unescape(params[:search][:name])
		character = Character.first(:conditions => ["rank_region = ? AND name ILIKE ? AND character_code = ?", params[:search][:region], params[:search][:name], params[:search][:code].to_i])
		
		unless character
			flash[:error] = "Sorry, cannot find anyone with from #{REGION_NAMES[params[:search][:region]]} as #{params[:search][:name]}##{params[:search][:code]}. You can try the Profile Finder, due to Battle Net changes, you won't be able to find a character by code all the time (despite them being in the database)."
			flash[:force_region] = params[:search][:region]
			flash[:tab_type] = "character_code"
			redirect_to root_path
			return
		end
		
		redirect_to character_path(character.region, character.bnet_id, character.name)
	end

	def search
		if params[:search].nil? || params[:search][:name].blank?
			flash[:tab_type] = "character_search"
			flash[:error] = "You must enter a name to search for."
			redirect_to root_path
			return
		end
		
		cookies[:search_region] = params[:search][:region]
		redirect_to search_special_path(params[:search][:type], params[:search][:region], CGI::unescape(params[:search][:name].strip))
	end
end
