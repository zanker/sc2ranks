module RankingsHelper
	def twitter_news()
		begin
			tweet = YAML::load(open(File.join(Rails.root, "public", "last_tweet")))
		rescue Exception => e
			return ""
		end
		
		#created_at = Time.parse(tweet[:created_at])
		#return "#{link_to(content_tag(:span, short_relative_time(created_at), :class => "jstime #{created_at.to_i}"), "http://twitter.com/sc2ranks")}: #{auto_link(tweet[:text])}"
		return "#{link_to(content_tag(:span, "@sc2ranks"), "http://twitter.com/sc2ranks")}: #{auto_link(tweet[:text])}"
	end
	
	def character_stats(stats)
		text = ["#{can_link_to("Total", stats_region_path("all", "all", "all"))}: #{number_with_delimiter(stats["total"])}"]
		stats.each do |region, chars|
			next if region == "total"
			text.push("#{can_link_to("%s", stats_region_path("all", "all", "all"))}: %s" % [REGION_NAMES[region], number_with_delimiter(chars)])
		end
		
		return text.join(", ")
	end

	def division_stats(stats)
		text = ["Total divisions: #{wrap_number(number_with_delimiter(stats["total"]))}"]
		stats.each do |region, chars|
			next if region == "total"
			text.push("%s: #{wrap_number("%s")}" % [REGION_NAMES[region], number_with_delimiter(chars)])
		end
		
		return text.join(", ")
	end
	
	def division_name(division)
		if division["is_random"].blank?
			return "#{division["bracket"]}v#{division["bracket"]}"
		else
			return "#{division["bracket"]}v#{division["bracket"]} (R)"
		end
	end
	
	def build_top_team_graph
		points_all = []
		points_recent = []
				
		Team.all(:conditions => ["league = ? AND bracket = ? AND is_random = ? AND teams.division_id IS NOT NULL", DEFAULT_LEAGUE, 1, false], :order => "points DESC", :limit => 10, :include => :first_character).each do |team|
			recent_series = {:name => team.first_character.full_name, :data => []}
			all_series = {:name => team.first_character.full_name, :data => []}
			
			previous_day = nil
			team.histories.all(:select => "*", :conditions => ["team_history_periods.created_at >= ? AND team_history_periods.created_at >= ?", 1.month.ago.midnight, Time.parse("April 11th, 2011 UTC")], :joins => "LEFT JOIN team_history_periods ON (team_histories.id >= team_history_periods.starts_at AND team_histories.id <= team_history_periods.ends_at)", :order => "team_history_periods.created_at DESC").each do |history|
				next if history.created_at.nil?
				created_at = Time.parse(history.created_at)

				if previous_day.nil? || (previous_day + 7.days) < created_at
					all_series[:data].push([created_at.to_s(:js), history.points])
					previous_day = created_at
				end
				
				recent_series[:data].push([created_at.to_s(:js), history.points]) if created_at >= 7.days.ago.midnight
			end
			
			points_all.push(all_series)
			points_recent.push(recent_series) if recent_series[:data].length > 0
		end
		
		return javascript_tag("var points_all_data = #{points_all.to_json};\nvar points_recent_data = #{points_recent.to_json};")
	end
		
	def short_relative_time(updated_at)
		diff = Time.now.utc - updated_at
		if diff < 1.minute
			return "<1 min"
		elsif diff < 60.minutes
			return pluralize((diff / 60).to_i, "min", "mins")
		elsif diff < 24.hours
			return pluralize((diff / (60 * 60)).to_i, "hour", "hours")
		else
			return pluralize((diff / (60 * 60 * 24)).to_i, "day", "days")
		end
	end
	
	def build_rows(rankings, args)
		args[:offset] ||= 0
		team_size = args[:is_random] ? 1 : args[:bracket]
		#show_losses = args[:league] == "all" ? true : (args[:league] >= LEAGUES["master"])
		show_losses = true		

		placement = args[:offset]
		previous_points = nil
		skipped_increments = 0
		
		html_rows = ""
		rankings.each do |team|
			next if team.division.nil?
			if previous_points.nil? || previous_points != team.points
				placement += 1 + skipped_increments
				skipped_increments = 0
			else
				skipped_increments += 1
			end
			previous_points = team.points

			html = ""
			html << content_tag(:td, (args[:division] ? team_badge(team, "19x20") : "" ) << number_with_delimiter(placement), :class => "rank") unless args[:no_ranks]
			html << content_tag(:td, can_link_to(SHORT_REGIONS[team.region], rank_filter_path(team.region, LEAGUES[team.league], team.bracket)), :class => "region") unless args[:division] || args[:region]
			
			if team_size == 1
				unless args[:region] or args[:no_ranks] or show_losses
					html << content_tag(:td, number_with_delimiter(team.region_rank), :class => "regionrank")
				end

				if ( args[:region] or args[:division] ) and !show_losses
					html << content_tag(:td, number_with_delimiter(team.world_rank), :class => "worldrank")
				end
			end
			
			highlight_row = nil
			id = 0
			team.team_characters.each do |relation|
				character = relation.character
					
				if character.nil?
					if id < team_size
						html << content_tag(:td, "&nbsp;", :class => "character#{id} character")
					end
				elsif character and !character.region
					next
				else
					highlight_row = true if args[:character_id] == character.id
			
					race = RACES[relation.played_race]
					html << content_tag(:td, image_tag("#{race || "unknown"}.png", :class => race) << can_link_to(character.full_name, character_path(character.region, character.bnet_id, character.name)), :class => "character#{id} character")
				end

				id += 1
			end
			
			if params[:sort] == "pointpool"
				max_pool = team.region_pool.max_pool
				unless team.is_random
					if team.bracket == 2
						max_pool = max_pool * 0.66
					elsif team.bracket == 3 or team.bracket == 4
						max_pool = max_pool * 0.33
					end
				end

				points = wrap_number(number_with_delimiter(team.points - max_pool.to_i)) << " (#{number_with_delimiter(team.points)})"
			elsif params[:action] == "masters"
			  team.points -= team.region_pool.max_pool if params[:poolsort].to_i > 0
				points = wrap_number(number_with_delimiter(team.points - team.division.modifier)) + " (#{number_with_delimiter(team.points)})"
			else
				points = number_with_delimiter(team.points)
			end
			
			if ( args[:league] == "all" or !show_losses ) and !args[:division]
				html << content_tag(:td, team_badge(team, "19x20") << points, :class => "points")
			else
				html << content_tag(:td, points, :class => "points")
			end
		
			html << content_tag(:td, number_with_delimiter(team.wins), :class => "wins green") unless team_size == 4
			if team_size != 4 and show_losses
				html << content_tag(:td, (team.has_losses? ? number_with_delimiter(team.losses) : "----"), :class => "losses#{team.has_losses? && " red" || ""}")
			end
			html << content_tag(:td, (team.has_losses? ? "%.2f%%" % [team.win_ratio * 100] : "----"), :class => "ratio") unless ( args[:league] == "all" && team_size >= 3 && args[:region].blank? ) or !show_losses
			
			unless args[:division]
				division = can_link_to(team.division.simple_name, rank_division_path(team.division.id, parameterize(team.division.name)))
				if team_size == 1
					if team.league == LEAGUES["grandmaster"]
						html << content_tag(:td, "#%d" % [team.division_rank], :class => "divisiongm")
					else
						html << content_tag(:td, "%s (#%d)" % [division, team.division_rank], :class => "division")
					end
				end
				
				if team_size == 2 && !args[:region].blank?
					html << content_tag(:td, division, :class => "division")
				end
			end
			
			html << content_tag(:td, short_relative_time(team.division.updated_at), :class => "age shortjstime #{team.division.updated_at.utc.to_i}")
			html_rows << content_tag(:tr, html, :class => "tblrow #{cycle("darkbg", "lightbg")}#{highlight_row && " highlight" || ""}")
		end
		
		return html_rows
	end
	
	def build_columns(args)
		team_size = args[:is_random] ? 1 : args[:bracket]
		#show_losses = args[:league] == "all" ? true : (args[:league] >= LEAGUES["master"])
		show_losses = true
	
		html = ""
		html << content_tag(:th, "Rank", :id => "rank") unless args[:no_ranks]
		html << content_tag(:th, "Region", :id => "region") unless args[:division] || args[:region]

		if team_size == 1
			unless args[:region] or args[:no_ranks] or show_losses
				html << content_tag(:th, "Region Rank", :id => "regionrank")
			end
		
			if ( args[:region] or args[:division] ) and !show_losses
				html << content_tag(:th, "World Rank", :id => "worldrank")
			end
		end
		
		team_size.times do |i|
			html << content_tag(:th, "Character", :id => "character#{i}", :class => "character")
		end
		
		html << content_tag(:th, "Points", :id => "points")
		html << content_tag(:th, "Wins", :id => "wins") unless team_size == 4
		html << content_tag(:th, "Losses", :id => "losses") unless team_size == 4 or !show_losses
		html << content_tag(:th, "Ratio", :id => "ratio") unless ( args[:league] == "all" && team_size >= 3 && args[:region].blank? ) or !show_losses
		
		if args[:division].nil? && ( team_size == 1  || team_size == 2 && args[:region] )
			if args[:league] == LEAGUES["grandmaster"]
				html << content_tag(:th, "Division Rank", :id => "divisiongm")
			else
				html << content_tag(:th, "Division", :id => "division")
			end
		end
		
		html << content_tag(:th, "Age", :id => "age")
		
		return html
	end
end
