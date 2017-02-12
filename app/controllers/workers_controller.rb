class WorkersController < ApplicationController
	def index
		unless read_fragment("workers", :raw => true, :expires_in => 10.minutes)
			season = nil
			RANK_REGIONS.each_value do |region|
				region_season = Rails.cache.read("seasoncur/#{region}", :raw => true).to_i
				next unless region_season > 0
				if !season or season < region_season
					season = region_season
				end 
			end				

			unless season
				season = Rails.cache.fetch("seasoncur/all", :expires_in => 30.minutes, :raw => true) do
					char = Character.first(:select => "MAX(season) as season")
					char && char.season || 8
				end.to_i
			end
			
			season = 9 unless season > 0

			@regions = {}
			#Division.all(:select => "region, league, COUNT(*) as total, EXTRACT(epoch FROM AVG((now() AT TIME ZONE 'UTC') - updated_at)) as average_age, MIN(updated_at) as oldest_record, MAX(updated_at) AS newest_record", :group => "region, league").each do |division|
			Division.all(:select => "region, league, COUNT(*) as total, EXTRACT(epoch FROM AVG((now() AT TIME ZONE 'UTC') - updated_at)) as average_age, MIN(updated_at) as oldest_record, MAX(updated_at) AS newest_record", :conditions => ["season = ? AND total_teams > 0", season], :group => "region, league").each do |division|
				league = division.league.to_i
			
				@regions[division.region] ||= {:total => 0}
				@regions[division.region][:total] += division.total.to_i

				@regions[division.region][league] ||= {}
				@regions[division.region][league][:total] = division.total.to_i
				@regions[division.region][league][:average_age] = division.average_age.to_i
				@regions[division.region][league][:oldest_record] = Time.parse(division.oldest_record + " UTC")
				@regions[division.region][league][:newest_record] = Time.parse(division.newest_record + " UTC")
				@regions[division.region][league][:total_dead] = Division.count(:conditions => {:total_teams => 0, :league => league, :region => division.region}) || 0
			end
		
			# do global
			#division = Division.first(:select => "region, league, COUNT(*) as total, EXTRACT(epoch FROM AVG((now() AT TIME ZONE 'UTC') - updated_at)) as average_age, MIN(updated_at) as oldest_record, MAX(updated_at) AS newest_record", :group => "league")
			Division.all(:select => "league, COUNT(*) as total, EXTRACT(epoch FROM AVG((now() AT TIME ZONE 'UTC') - updated_at)) as average_age, MIN(updated_at) as oldest_record, MAX(updated_at) AS newest_record",  :conditions => ["season = ? AND total_teams > 0", season], :group => "league").each do |division|
				league = division.league.to_i
				
				@regions["global"] ||= {:total => 0}
				@regions["global"][:total] += division.total.to_i
			
				@regions["global"][league] ||= {}
				@regions["global"][league][:total] = division.total.to_i
				@regions["global"][league][:average_age] = division.average_age.to_i
				@regions["global"][league][:oldest_record] = Time.parse(division.oldest_record + " UTC")
				@regions["global"][league][:newest_record] = Time.parse(division.newest_record + " UTC")
				@regions["global"][league][:total_dead] = Division.count(:conditions => {:total_teams => 0, :league => league}) || 0
			end
		end
	end
end
