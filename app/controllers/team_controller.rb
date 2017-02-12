class TeamController < ApplicationController
	def index
		team_id = params[:team_id].to_i
		
		# Despite relations being a one-to-one relation, the query itself doesn't do LIMIT 1
		# which means if we want to take advantage of query caching, we have to do an all and then just grab the first
		@team = Team.first(:conditions => {:id => team_id}, :include => :division)
		if @team.nil?
			flash[:error] = "Cannot find team"
			redirect_to root_path
			return
		end

		# This lets us quickly invalidate all team caches without updating team keys
		@page_hash = "#{@team.cache_key}/#{@team.division.cache_key}/#{Rails.cache.read("logs/generated", :raw => true, :expires_in => 48.hours)}" rescue nil
		if @page_hash.nil?
			flash[:error] = "Cannot find team"
			redirect_to root_path
			return
		end
	end
	
	def team_history
		team = Team.first(:conditions => {:id => params[:team_id].to_i})
		unless team
			return render :json => {:error => :no_team}
		end
		
		if params[:year] && params[:month]
			render :json => team.build_history(Time.utc(params[:year].to_i, params[:month].to_i, 1, 0, 0, 0));
		else
			render :json => team.build_history;
		end
	end
end
