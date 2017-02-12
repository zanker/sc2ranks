require "cgi"
class ProfileSearchController < ApplicationController
	def index
		region = REGIONS.include?(params[:region].downcase) ? params[:region].downcase : "us"
		name = CGI::unescape(params[:name])
		type = params[:type].downcase
		sub_type = params[:sub_type].downcase
		value = sub_type != "division" ? params[:value].to_i : CGI::unescape(params[:value].downcase)
		
		bracket = type.match("([0-9]+)")
		bracket = bracket && bracket[0].to_i > 0 ? bracket[0].to_i : nil
		
		if bracket
			sub_type = sub_type == "wins" && "wins" || sub_type == "losses" && "losses" || sub_type == "division" && "division" || "points"
		else
			sub_type = "points"
		end

		@page_hash = Digest::SHA1.hexdigest("search/profile/#{region}/#{name}/#{type}/#{sub_type}/#{value}")
			
		etag = Rails.cache.read("#{@page_hash}/etag", :raw => true, :expires_in => 30.minutes) 
		return unless etag.nil? || stale?(:etag => etag)
		
		unless read_fragment(@page_hash, :raw => true, :expires_in => 30.minutes)
			Rails.cache.write("#{@page_hash}/etag", "#{@page_hash}/#{Time.now.to_i}", :raw => true, :expires_in => 30.minutes)
			
			conditions = ["characters.region = ? AND characters.name = ?", region, name]

			joins = nil
			if bracket
				joins = "LEFT JOIN team_characters ON team_characters.character_id = characters.id LEFT JOIN teams ON teams.id = team_characters.team_id"
				
				conditions[0] << " AND teams.bracket = ? AND teams.division_id IS NOT NULL"
				conditions.push(bracket)
				
				if sub_type == "division"
					joins << " LEFT JOIN divisions ON divisions.id=teams.division_id"
					
					conditions[0] << " AND divisions.name ILIKE ?"
					conditions.push("%#{value}%")
				else
				  value = value.to_i
					conditions[0] << " AND teams.#{sub_type} <= ? AND teams.#{sub_type} >= ?"
					conditions.push(value + 50, value - 50)
				end
			else
			  value = value.to_i

				conditions[0] << " AND characters.achievement_points <= ? AND characters.achievement_points >= ?"
				conditions.push(value + 100, value - 100)
			end
			
			@char_list = []
			Character.all(:select => "characters.*", :conditions => conditions, :joins => joins, :include => {:teams => :division}, :limit => 100).each do |character|
				team = nil
				character.teams.each do |team_data|
					next if team_data.division_id.nil?	
					
					if !bracket.nil?
						team = team_data if team.nil? || team_data.bracket == bracket
					else
						team = team_data if team_data && ( team.nil? || team.points < team_data.points || team.league < team_data.league )
					end
				end
				
				next if team.nil?
				
				character[:team] = team
				@char_list.push(character)
			end
			
			if @char_list.length == 1
				character = @char_list.first
				redirect_to character_path(character.region, character.bnet_id, character.name)
			end
		end
	end
	
	def search
		if params[:psearch].nil? || params[:psearch][:name].blank?
			flash[:tab_type] = "profile_search"
			flash[:error] = "You must enter a name to search for."
			redirect_to root_path
			return
		end
		
		redirect_to profile_search_path(params[:psearch])
	end
end
