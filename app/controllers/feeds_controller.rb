class FeedsController < ApplicationController
	def replays
		@character = Character.first(:conditions => {:id => params[:character_id].to_i})
		unless @character
			render :json => {:error => "no_character"}, :status => 500
			return
		end
		
		page_hash = "feed/replays/#{@character.cache_key}"
		
		etag = Rails.cache.read("#{page_hash}/etag", :raw => true, :expires_in => 24.hours) 
		return unless etag.nil? || stale?(:etag => etag)
		Rails.cache.fetch("#{page_hash}/etag", :raw => true, :expires_in => 24.hours) do "#{Time.now.to_i}/#{page_hash}" end
		
		@replays = @character.replays.all(:order => "played_on DESC", :limit => 25, :include => [:map, :replay_characters, :characters])
			
		respond_to do |wants|
			wants.atom { render :layout => "replays.atom" }
			wants.rss { render :layout => "replays.rss" }
		end
	end
	
	def match_history
		@character = Character.first(:conditions => {:id => params[:character_id].to_i})
		unless @character
			render :json => {:error => "no_character"}, :status => 500
			return
		end
		
		page_hash = "feed/match/#{@character.cache_key}"
		
		etag = Rails.cache.read("#{page_hash}/etag", :raw => true, :expires_in => 24.hours) 
		return unless etag.nil? || stale?(:etag => etag)
		Rails.cache.fetch("#{page_hash}/etag", :raw => true, :expires_in => 24.hours) do "#{Time.now.to_i}/#{page_hash}" end
		
		@matches = @character.matches.all(:order => "played_on DESC", :limit => 25, :include => :map)
		respond_to do |wants|
			wants.atom { render :layout => "match_history.atom" }
			wants.rss { render :layout => "match_history.rss" }
		end
	end
	
	def team_history
		@team = Team.first(:conditions => {:id => params[:team_id].to_i})
		unless @team
			render :json => {:error => "no_team"}, :status => 500
			return
		end

		page_hash = "feed/team/history/#{@team.cache_key}"
		
		etag = Rails.cache.read("#{page_hash}/etag", :raw => true, :expires_in => 24.hours) 
		return unless etag.nil? || stale?(:etag => etag)
		Rails.cache.fetch("#{page_hash}/etag", :raw => true, :expires_in => 24.hours) do "#{Time.now.to_i}/#{page_hash}" end
		
		@records = []
		last_id, last_history = nil, nil
		@team.histories.all(:select => "*", :joins => "LEFT JOIN team_history_periods ON (team_histories.id >= team_history_periods.starts_at AND team_histories.id <= team_history_periods.ends_at)", :order => "team_history_periods.created_at DESC", :limit => 25).each do |history|
			next if history.created_at.nil?

			created_at = Time.parse(history.created_at)
			last_id = history.id
			next if last_history && last_history.world_rank == history.world_rank && last_history.points == history.points && last_history.league == history.league

			@records.push(:world_rank => history.world_rank, :points => history.points, :league => history.league, :created_at => created_at, :id => history.id)

			last_history = history
		end

		# Find the last ID if we need to
		if @records.last && @records.last[:id] != last_id
			@records.last[:created_at] = TeamHistoryPeriod.first(:conditions => ["? <= ends_at AND starts_at >= ?", last_id, last_id]).created_at
		end
			
		respond_to do |wants|
			wants.atom { render :layout => "match_history.atom" }
			wants.rss { render :layout => "match_history.rss" }
		end
	end
end
