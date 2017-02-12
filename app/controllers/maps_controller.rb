class MapsController < ApplicationController
	def rankings
		@region = RANK_REGIONS_LIST.include?(params[:region]) ? params[:region] : nil
		@offset = params[:offset].to_i
		@page_hash = Digest::SHA1.hexdigest("map/ranks/#{@region}/#{@offset}")
					
		etag = Rails.cache.read("#{@page_hash}/etag", :raw => true, :expires_in => 1.hour) 
		return unless !flash[:message].blank? || !flash[:error].blank? || etag.nil? || stale?(:etag => etag)
		
		unless read_fragment(@page_hash, :raw => true, :expires_in => 1.hour)
			Rails.cache.write("#{@page_hash}/etag", "#{@page_hash}/#{Time.now.to_i}", :raw => true, :expires_in => 1.hour)
			
			conditions = @region && {:region => @region}
			
			@total_maps = (Rails.cache.fetch("map/totals/#{@region}", :raw => true, :expires_in => 50.minutes) do
				Map.count(:conditions => conditions)
			end).to_i
			
			# Postgres will error if we don't list all of the columns in the group by blah blah, so do two queries
			@rankings = Map.all(:conditions => conditions, :order => "total_games DESC", :offset => @offset, :limit => 100, :include => :overall_stat)
			
			# Do rankings and find map id list quickly
			previous_games = nil
			skipped_increments = 0
			placement = @offset

			map_ids = []
			@rankings.each do |map|
				if previous_games.nil? || previous_games != map.total_games
					placement += 1 + skipped_increments
					skipped_increments = 0
				else
					skipped_increments += 1
				end
				
				previous_points = map.total_games

				map[:rank] = placement
			end
		end
	end
	
	def index
		@map = Map.first(:conditions => {:id => params[:id].to_i})
		unless @map
			flash[:error] = "Invalid map id passed."
			return redirect_to root_path
		end
		
		unless read_fragment("map/stats/#{@map.id}", :expires_in => 3.hours)
			@stats = {}

			# All time
			@stats[:all] = @map.overall_stat ? @map.overall_stat.total_games : 0
			# Games in the last 24 hours
			@stats[:day] = @map.	stats.sum(:total_games, :conditions => ["stat_date > ?", 24.hours.ago.midnight])
			# Games in the last week
			@stats[:week] = @map.stats.sum(:total_games, :conditions => ["stat_date > ?", 1.week.ago.midnight])
			# Games in the last month
			@stats[:month] = @map.stats.sum(:total_games, :conditions => ["stat_date > ?", 1.month.ago.midnight])
		end
	end
end
