module StatsHelper
	def patch_tag(patch)
		return patch == LATEST_PATCH ? content_tag(:span, " (live)", :class => "green") : content_tag(:span, " (old patch)", :class => "red")
	end
	
	def stat_info(args)
		text = "#{args[:text]} stats for"
		if args[:group]
			text << " the top #{wrap_number(number_with_delimiter(args[:group]))} players in"
		elsif args[:total]
			text << " "
			text << wrap_number(number_with_delimiter(args[:total]))
		end
		
		text << (args[:is_random] ? " random teams" : " teams")
		text << " from"

		if args[:league]
			text << " the "
			text << wrap_number(args[:league].capitalize)
			text << " leagues" unless args[:bracket]
		end

		if args.has_key?(:bracket)
			if args[:bracket]
				text << " "
				text << wrap_number("#{args[:bracket]}v#{args[:bracket]}")
				text << " brackets"
			elsif args[:league]
				text << " and every bracket"
			else
				text << " every bracket"
			end
		end
		
		if args.has_key?(:league) && args[:league].nil?
			if args.has_key?(:bracket) && args[:bracket].nil?
				text << " and league"
			elsif args[:bracket]
				text << " in every league"
			end
		end
		
		if args.has_key?(:region)
			if args[:region]
				text << " in "
				text << wrap_number(REGION_NAMES[args[:region]])
			else
				text << " in all regions"
			end
		end
		
		if args[:activity]
			text << " and played a game since #{wrap_number(args[:activity].days.ago.to_s(:short_date))}"
		end
			
		if args[:expansion]
			text << " for #{wrap_number(EXPANSIONS[args[:expansion].to_i])}"
		end

		return text << "."
	end
	
	def create_league_race_distribution(distrib)
		series = []
		
		avail_leagues = []
		LEAGUE_LIST.each do |league|
			if distrib[league]
				avail_leagues.push(LEAGUE_NAMES[league])
			end
		end

		RACE_LIST.each do |race|
			race_series = {:name => RACE_NAMES[race], :data => []}

			LEAGUE_LIST.each do |league|
				if distrib[league] && distrib[league][race]
					race_series[:data].push(distrib[league][race])
				end
			end
						
			series.push(race_series)
		end
		
		series.first[:data].length.times do |id|
			total = 0
			series.each do |race_series|
				total += race_series[:data][id] if race_series[:data][id]
			end
			
			series.each do |race_series|
				race_series[:data][id] = race_series[:data][id].to_f / total
			end
		end
	
		return javascript_tag("var race_distribution = #{series.to_json};\nvar xaxis_list = #{avail_leagues.to_json};")
	end
	
	def create_overall(population)
		pop_series = []
		population.each do |region, stats|
			stats.each do |stat|
				stat[0] = stat[0].to_s(:js_date)
			end
			
			pop_series.push({:name => REGION_NAMES[region], :data => stats.reverse})
		end
		
		return javascript_tag("var population_series = #{pop_series.to_json};")
	end

	def create_region_race_distribution(distrib)
		series = []
		
		avail_regions = []
		REGIONS_GLOBAL.each do |region|
			if distrib[region]
				avail_regions.push(region == "global" ? "All" : region.upcase)
			end
		end

		RACE_LIST.each do |race|
			race_series = {:name => RACE_NAMES[race], :data => []}

			REGIONS_GLOBAL.each do |region|
				if distrib[region] && distrib[region][race]
					race_series[:data].push(distrib[region][race] || 0)
				end
			end
			
			series.push(race_series)
		end

		series.first[:data].length.times do |id|
			total = 0
			series.each do |race_series|
				total += race_series[:data][id] if race_series[:data][id]
			end
			
			series.each do |race_series|
				race_series[:data][id] = race_series[:data][id].to_f / total if race_series[:data][id]
			end
		end
		
		return javascript_tag("var race_distribution = #{series.to_json};\nvar xaxis_list = #{avail_regions.to_json};")
	end
	
	def create_points_race_distribution(distrib)
		series = {}
		slices = {}
		
		# Figure out point slices first
		LEAGUE_LIST.each do |league|
			next unless distrib[league]
			
			points = []
			RACE_LIST.each do |race|
				if distrib[league][race]
					points = points | distrib[league][race].keys
				end
			end
			
			if points.length == 0
				next
			end
			
			# Figure out the last slice so we can figure out if that slice is bad
			points.sort!
			slice_offset = points.last - (points.last % 100) + 1
			
			total_at_last = 0
			total_at_second = 0
			points.reverse_each do |point|
				if point > slice_offset
					total_at_last += 1
				end
				
				if point > (slice_offset - 100) && point <= slice_offset
					total_at_second += 1
				end	
			end
			
			# We only have 2 or more in the last slice, and that's more than the previous slice has, will merge them
			slice_offset = slice_offset - 100 if total_at_last <= 2 && total_at_second >= total_at_last
			
			# Now unique it and figure out the rest of the slices
			points.uniq!
			
			slices[league] ||= []
			
			# First slice
			first_slice = points.first - (points.first % 100) + 1
			
			# Now go as far as we can back
			10.times do |i|
				break if slice_offset <= first_slice
				slices[league].push(slice_offset)
				slice_offset -= 100
			end
			
			slices[league].push(first_slice) if first_slice < slices[league].last.to_i
			slices[league].reverse!
		end
		
		# Now go back and reloop to figure out distribution
		LEAGUE_LIST.each do |league|
			next unless distrib[league] && slices[league]

			RACE_LIST.each do |race|
				race_series = {:name => RACE_NAMES[race], :data => []}
				
				slice_distrib = {}
				
				# Create slice from data
				next if distrib[league][race].nil?
				distrib[league][race].each do |points, total|
					first_slice = slices[league].first
					last_slice = slices[league].last
					
					slices[league].each_index do |id|
						slice = slices[league][id]
						next_slice = slices[league][id + 1]
						if ( next_slice && points < next_slice && points >= slice ) || ( next_slice.nil? && points >= slice )
							slice_distrib[slice] ||= 0
							slice_distrib[slice] += total
						end
					end
				end
				
				# Now add it all including blanks
				total = 0
				slices[league].each do |slice|
					race_series[:data].push(slice_distrib[slice] || 0)
					total += (slice_distrib[slice] || 0)
				end
				
				race_series[:data].push(total)
												
				series[league] ||= []
				series[league].push(race_series)
			end
			
			# Now go back and figure out the percentages
			series.values.each do |race_series|
				race_series.first[:data].length.times do |id|
					total = 0
					
					race_series.each do |race|
						total += (race[:data][id] || 0)
					end
															
					race_series.each do |race|
						race[:data][id] = (race[:data][id].to_f / total)
					end
				end
			end
						
			# Go back over slices one final time and make them usable for everyone else
			slices[league].each_index do |id|
				if id == 0
					slices[league][id] = "#{slices[league][id]} - #{slices[league][id + 1] - 1}"
				elsif slices[league][id + 1]
					slices[league][id] = slices[league][id]
				else
					slices[league][id] = "#{slices[league][id]}+"
				end
			end

			# Total
			slices[league].push("Overall")
		end
		
		return javascript_tag("var points_data = #{series.to_json};\nvar points_slice = #{slices.to_json};")
	end
		
	def format_stat_number(tbl, key, force_int=false)
		if tbl && tbl[key]
			if tbl[key].is_a?(Integer)
				return "#{wrap_number("%.1f%")} (%s)" % [(tbl[key].to_f / tbl[:total]) * 100, number_with_delimiter(tbl[key])]
			elsif tbl[key][:average]
				return wrap_number("%s") % [number_with_delimiter(tbl[key][:average])]
			elsif tbl[key][:total]
				if force_int
					return wrap_number(number_with_delimiter(tbl[key][:total]))
				else
					return "#{wrap_number("%.1f%")} (%s)" % [(tbl[key][:wins].to_f / tbl[key][:total]) * 100, number_with_delimiter(tbl[key][:total])]
				end
			end
		end
	end
end
