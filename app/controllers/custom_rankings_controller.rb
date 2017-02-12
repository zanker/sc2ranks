class CustomRankingsController < ApplicationController
	# List logs and bans
	def logs
		@custom = CustomRanking.first(:conditions => {:id => params[:id].to_i})
		if @custom.nil?
			flash[:error] = "Failed to find division."
			redirect_to root_path
			return
		# IP banned, how sad
		elsif @custom.bans.exists?(:ip_address => request.remote_ip)
			flash[:error] = "You have been banned from division management."
			redirect_to custom_division_path(@custom.id)
			return
		# Failed to cookie auth
		elsif !@custom.is_authed?(cookies)
			flash[:error] = "Failed to authorize, you are not logged in yet."
			redirect_to custom_division_path(params[:id])
			return
		end
	end

	# Reverting a log action
	def revert_log
		log = CustomRankingLogs.first(:conditions => {:id => params[:id].to_i})
		# Double check, double check, double check
		if log.nil? || log.division.nil?
			flash[:error] = "Failed to find log or division"
			redirect_to root_path
			return
		# Double check authorization
		elsif !log.division.is_authed?(cookies)
			flash[:error] = "Failed to authorize."
			redirect_to custom_division_path(log.division.id)
			return
		elsif log.division.bans.exists?(:ip_address => request.remote_ip)
			flash[:error] = "You have been banned from division management."
			redirect_to custom_division_path(log.division.id)
			return
		end
		
		# Removed, or it was an add that got reverted
		if log.action_type == LOG_TYPES[:removed] || log.action_type == LOG_TYPES[:reverted_add]
			log.character_ids.split(",").each do |character_id|
				# Sanity check before adding
				if Character.exists?(:id => character_id)
					CustomRankingCharacter.create(:custom_ranking_id => log.division.id, :character_id => character_id.to_i)
				end
			end

			CustomRankingLogs.create(:custom_ranking_id => log.division.id, :character_ids => log.character_ids, :action_type => LOG_TYPES[:reverted_remove], :ip_address => request.remote_ip)
		# Add, or a remove that got reverted
		elsif log.action_type == LOG_TYPES[:added] || log.action_type == LOG_TYPES[:reverted_remove]
			CustomRankingCharacter.delete_all(["custom_ranking_id = ? AND character_id IN (?)", log.division.id, log.character_ids.split(",")])
			CustomRankingLogs.create(:custom_ranking_id => log.division.id, :character_ids => log.character_ids, :action_type => LOG_TYPES[:reverted_add], :ip_address => request.remote_ip)
		end
		
		flash[:message] = "Changes by #{log.ip_address} reverted!"

		redirect_to custom_div_logs_path(log.division.id)
	end
	
	# Unbanning an IP
	def unban
		ban = CustomRankingBans.first(:conditions => {:id => params[:id].to_i})
		if ban.nil? || ban.division.nil?
			flash[:error] = "Failed to find ban or division"
			redirect_to root_path
			return
		# Authorize
		elsif !ban.division.is_authed?(cookies)
			flash[:error] = "Failed to authorize."
			redirect_to root_path
			return
		elsif ban.division.bans.exists?(:ip_address => request.remote_ip)
			flash[:error] = "You have been banned from division management."
			redirect_to custom_division_path(ban.division.id)
			return
		end
		
		ban.delete
		flash[:message] = "Unbanned #{ban.ip_address}!"
		redirect_to custom_div_logs_path(ban.division.id)
	end
	
	# Banning an IP
	def ban
		log = CustomRankingLogs.first(:conditions => {:id => params[:id].to_i})
		if log.nil? || log.division.nil?
			flash[:error] = "Failed to find log or division"
			redirect_to root_path
			return
		# Authorize
		elsif !log.division.is_authed?(cookies)
			flash[:error] = "Failed to authorize."
			redirect_to root_path
			return
		elsif log.division.bans.exists?(:ip_address => request.remote_ip)
			flash[:error] = "You have been banned from division management."
			redirect_to custom_division_path(log.division.id)
			return
		# Make sure they aren't being stupid
		elsif log.ip_address == request.remote_ip
			flash[:error] = "You cannot ban yourself."
			redirect_to custom_div_logs_path(log.division.id)
			return
		end
		
		unless log.division.bans.exists?(:ip_address => log.ip_address)
			CustomRankingBans.create(:ip_address => log.ip_address, :custom_ranking_id => log.division.id)
		end
		
		flash[:message] = "Banned IP #{log.ip_address}"
		redirect_to custom_div_logs_path(log.division.id)
	end
	
	# Listing divisions
	def list
	end
	
	# New division
	def new
	end
	
	# Managing divisions
	def manage
		@custom = CustomRanking.first(:conditions => {:id => params[:id].to_i})
		unless @custom
			flash[:error] = "Invalid custom division id #{params[:id].to_i}"
			redirect_to root_path
			return
		end

		# Check ban
		if @custom.bans.exists?(:ip_address => request.remote_ip)
			flash[:error] = "You have been banned from division management."
			redirect_to custom_division_name_path(@custom.id, parameterize(@custom.name))
			return
		end
	end
	
	# Updating/creating divisionss
	def update
		@custom = params[:id] && CustomRanking.first(:conditions => {:id => params[:id].to_i})
		# Updating a divison that we couldn't find
		if params[:id] && @custom.nil?
			flash[:error] = "Invalid custom division id for updating #{params[:id]}"
			redirect_to root_path
			return
		# Updating division
		elsif @custom
			# Check bans
			if @custom.bans.exists?(:ip_address => request.remote_ip)
				flash[:error] = "You have been banned from division management."
				redirect_to custom_division_name_path(@custom.id, parameterize(@custom.name))
				return
			# Authorize, don't do cookie authorization for security
			elsif @custom.password != Digest::SHA1.hexdigest(params[:division][:auth_password] + @custom.password_salt)
				flash[:error] = "Failed to authorize, password incorrect."
				render :action => :manage
				return
			end
			
			# Kill it all
			if params[:division][:delete].to_i == 1
				flash[:message] = "Deleted division ##{@custom.id}"

				@custom.destroy
				redirect_to root_path
				return
			end
		end
		
		# Check password
		if @custom.nil? && ( params[:division][:password].blank? || params[:division][:confirm_password].blank? )
			flash[:error] = "You must fill out a password."
			render :action => @custom ? :manage : :new
			return
		elsif !params[:division][:password].blank? && params[:division][:password] != params[:division][:confirm_password]
			flash[:error] = "Passwords do not match."
			render :action => @custom ? :manage : :new
			return
		end
		
		# Check length
		if params[:division][:name].length > 30
			flash[:error] = "Division name is too long."
			render :action => @custom ? :manage : :new
			return
		end
		
		@custom ||= CustomRanking.new
		@custom.name = params[:division][:name].gsub(/<\/?[^>]*>|<!|javascript/,  "")
		@custom.message = params[:division][:message].gsub(/<\/?[^>]*>|<!|javascript/,  "")
		@custom.email = params[:division][:email] unless params[:division][:email].blank?
		@custom.allow_add = params[:division][:allow_add].to_i == 1 ? true : false
		@custom.allow_remove = params[:division][:allow_remove].to_i == 1 ? true : false
		#@custom.show_codes = params[:division][:show_codes].to_i == 1 ? true : false
		@custom.show_regions = params[:division][:show_regions].to_i == 1 ? true : false
		@custom.is_public = params[:division][:is_public].to_i == 1 ? true : false
		
		unless params[:division][:password].blank?
			@custom.password_salt = ActiveSupport::SecureRandom.hex(10)
			@custom.password = Digest::SHA1.hexdigest(params[:division][:password] + @custom.password_salt)
			
			# Reset our cookie for sessions so people have to relog in
			@custom.session_token = Digest::SHA1.hexdigest(ActiveSupport::SecureRandom.hex(30) + @custom.password_salt)
		end
		
		@custom.touch
		
		if @custom
			flash[:message] = "Division configuration updated!"
		else
			flash[:message] = "Custom division created!"
		end

		# Save login
		if params[:division][:remember].to_i == 1
			cookies["div#{@custom.id}"] = {:value => @custom.session_token, :expires => Time.now + 1.year}
		else
			cookies["div#{@custom.id}"] = {:value => @custom.session_token}
		end

		redirect_to custom_division_name_path(@custom.id, parameterize(@custom.name))
	end

	def manage_characters
		@custom = CustomRanking.first(:conditions => {:id => params[:id].to_i})
		unless @custom
			flash[:error] = "Invalid custom division id #{params[:id].to_i}"
			redirect_to root_path
			return
		end
		
		# Check if they were IP banned
		if @custom.bans.exists?(:ip_address => request.remote_ip)
			flash[:error] = "You have been banned from division management."
			redirect_to custom_division_name_path(@custom.id, parameterize(@custom.name))
			return
		end
	end
	
	def update_characters
		@custom = CustomRanking.first(:conditions => {:id => params[:id].to_i})
		unless @custom || ( params[:division][:char_type] != "add" && params[:division][:char_type] != "remove" ) 
			flash[:error] = "Invalid custom division id #{params[:id].to_i}"
			redirect_to root_path
			return
		end
		
		# Check for IP ban
		if @custom.bans.exists?(:ip_address => request.remote_ip)
			flash[:error] = "You have been banned from division management."
			redirect_to custom_division_name_path(@custom.id, parameterize(@custom.name))
			return
		end
		
		# Check if we need to use permissions
		if params[:division][:char_type] == "add" && @custom.allow_add.blank? || params[:division][:char_type] == "remove" && @custom.allow_remove.blank?
			if params[:division][:auth_password].nil? || @custom.password != Digest::SHA1.hexdigest(params[:division][:auth_password] + @custom.password_salt)
			 	if !@custom.is_authed?(cookies)
					flash[:error] = "Failed to authorize, password incorrect."
					render :action => :manage_characters
					return
				end
			end
		end
		
		# Save login, ONLY if they entered the password
		if !params[:division][:auth_password].nil? && @custom.password == Digest::SHA1.hexdigest(params[:division][:auth_password] + @custom.password_salt)
			if params[:division][:remember].to_i == 1
				cookies["div#{@custom.id}"] = {:value => @custom.session_token, :expires => Time.now + 1.year}
			else
				cookies["div#{@custom.id}"] = {:value => @custom.session_token}
			end
		end
				
		summary = []
		character_ids = []
		
		params[:division][:urls].split("\n").each do |url|
			# Parse out data
			character = CustomRankingCharacter.parse_url(url)

			# Confirm it's valid
			if character.length > 0 && character[:bnet_id] > 0 && REGIONS.include?(character[:region].downcase)
				data = Character.first(:conditions => {:region => character[:region], :bnet_id => character[:bnet_id]})
				# Queue if we don't have it yet
				unless data
					Armory::Queue.character(:region => character[:region], :bnet_id => character[:bnet_id], :name => character[:name], :tag => 16)
					summary.push("Queued #{character[:region]}-#{character[:name]}, name didn't exist")
				else
					character_ids.push(data.id)
						
					if params[:division][:char_type] == "add"
						summary.push("Added character #{character[:region].upcase}-#{character[:name]} to division list")
						
						unless CustomRankingCharacter.exists?(["character_id = ? AND custom_ranking_id = ?", data.id, @custom.id])
							CustomRankingCharacter.create(:character_id => data.id, :custom_ranking_id => @custom.id)
							
							# Grab character codes if we don't have one yet
							if data.character_code.nil?
								Armory::Queue.character(:region => data.region, :bnet_id => data.bnet_id, :name => data.name, :tag => 13, :no_cascade => true)
							end
						end
					else
						summary.push("Removed character #{character[:region].upcase}-#{character[:name]} from division list")
						CustomRankingCharacter.delete_all(["character_id = ? AND custom_ranking_id = ?", data.id, @custom.id])
					end
				end
			else
				summary.push("Failed to parse url #{url}")
			end
		end
		
		if summary.length > 0
			flash[:message] = summary.join("<br />")
		else
			flash[:message] = "No characters to update."
		end
		
		@custom.touch
		flash[:reset_ranks] = Time.now.to_i
		
		if character_ids.length > 0
			CustomRankingLogs.create(:custom_ranking_id => @custom.id, :ip_address => request.remote_ip, :character_ids => character_ids.join(","), :action_type => params[:division][:char_type] == "add" ? LOG_TYPES[:added] : LOG_TYPES[:removed])
		end
		
		redirect_to custom_division_name_path(@custom.id, parameterize(@custom.name))
	end
	
	def url_format
		if params[:filter].nil?
			flash[:error] = "Invalid request"
			redirect_to root_path
		else
			redirect_to custom_division_region_offset_path(params[:filter][:id], params[:filter][:region] || "all", params[:filter][:league], params[:filter][:bracket], params[:filter][:race], params[:filter][:sort], 0, params[:filter][:expansion])
		end
	end
	
	
	def index
		# Make sure this custom division exists
		custom_id = params[:id].to_i
		@custom = CustomRanking.first(:conditions => {:id => custom_id})
		unless @custom
			flash[:error] = "No custom division found with the id #{custom_id}."
			redirect_to root_path
			return
		end
		
		# Cache the list of character ids in this
		@custom_characters = Rails.cache.fetch("custom/players/#{@custom.cache_key}", :expires_in => 30.minutes) do
			list = []
			CustomRankingCharacter.all(:conditions => {:custom_ranking_id => custom_id}).each do |relation|
				list.push(relation.character_id)
			end
			
			list
		end
				
		# Do all the basic work
		@region = REGIONS.include?(params[:region]) && params[:region] || nil
		@league = ( params[:league] == "all" || params[:league].nil? ) ? nil : LEAGUES[params[:league]] || LEAGUES["diamond"]
		@bracket = params[:bracket] && params[:bracket].match(/([0-9]+)/)
		@bracket = @bracket && @bracket[1].to_i > 0 ? @bracket[1].to_i : 1
		@is_random = params[:bracket] && params[:bracket].match(/R/) ? true : false
		@offset = params[:offset].to_i
		@race = params[:race] && RACES[params[:race]] || "all"
                @expansion = CURRENT_EXPANSION
                if params.has_key?(:expansion)
	                @expansion = EXPANSIONS[params[:expansion].to_i] ? params[:expansion].to_i : CURRENT_EXPANSION
                end

		@sort_by = params[:sort] == "ratio" && "win_ratio" || params[:sort] == "comp" && "race_comp" || params[:sort] == "pointratio" && "(points * win_ratio)" || params[:sort] == "wins" && "wins" || params[:sort] == "losses" && "losses" || params[:sort] == "played" && "(wins + losses)" || "points"

		# If sort isn't set, then do points -> league
		@sort_by = "league DESC, #{@sort_by}" unless @league
		

		@page_hash = Digest::SHA1.hexdigest("ranks/custom/#{@region}/#{@bracket}/#{@offset}/#{@league}/#{@sort_by}/#{@is_random}/#{@race}/#{@custom.cache_key}/#{@expansion}")
						etag = Rails.cache.read("#{@page_hash}/etag", :raw => true, :expires_in => 2.hours) 
		return unless !flash[:message].blank? || !flash[:error].blank? || etag.nil? || stale?(:etag => etag)
		
		unless read_fragment(@page_hash, :raw => true, :expires_in => 2.hours)
			Rails.cache.write("#{@page_hash}/etag", "#{@page_hash}/#{Time.now.to_i}", :raw => true, :expires_in => 2.hours)
			query = ["teams.division_id IS NOT NULL AND bracket = :bracket AND is_random = :random AND team_characters.character_id IN(:characters) AND teams.expansion = :expansion", {:bracket => @bracket, :random => @is_random, :characters => @custom_characters, :expansion => @expansion}]			
			if @region
				query[0] << " AND region = :region"
				query[1][:region] = @region
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
		
			if @league
				query[0] << " AND league = :league"
				query[1][:league] = @league
			end
				
			# No sense in repulling total teams because that won't change very often
			@total_teams = (Rails.cache.fetch(Digest::SHA1.hexdigest("ranks/custom/#{@custom.cache_key}/#{@region}/#{@bracket}/#{@league}/#{@is_random}/#{@race}/#{@expansion}"), :raw => true, :expires_in => 6.hour) do
				Team.count(:all, :select => "hash_id", :distinct => true, :conditions => query, :joins => "LEFT JOIN team_characters ON team_characters.team_id=teams.id") || 0
			end).to_i
			
			
			@offset = @offset > @total_teams ? (@total_teams - 100) : @offset
			@offset = @offset < 0 ? 0 : @offset
			
			if RAILS_ENV == "production"
				#iteration = Team.find_by_sql("SELECT teams.* FROM (SELECT DISTINCT ON(hash_id) teams.* FROM teams LEFT JOIN team_characters ON team_characters.team_id=teams.id WHERE ( #{ActiveRecord::Base.send("sanitize_sql_for_conditions", query, "teams")} ) ) AS teams ORDER BY #{@sort_by} DESC LIMIT 100 OFFSET #{@offset};")
				iteration = Team.all(:select => "teams.*", :from => "(SELECT DISTINCT ON(hash_id) teams.* FROM teams LEFT JOIN team_characters ON team_characters.team_id=teams.id WHERE ( #{ActiveRecord::Base.send("sanitize_sql_for_conditions", query, "teams")} ) ) AS teams", :order => "#{@sort_by} DESC", :limit => 100, :offset => @offset, :include => [:division, :team_characters, :characters])
			else
				iteration = Team.all(:select => "teams.*", :conditions => query, :joins => "LEFT JOIN team_characters ON team_characters.team_id=teams.id", :order => "#{@sort_by} DESC", :limit => 100, :offset => @offset, :include => [:division, :team_characters, :characters])
			end
			
			@rankings = []
			iteration.each do |team|
				@rankings.push(team)
			end
		end
	end
end
