module TeamHelper
	def build_history_picker()
		months = []
		id = 0
		Date::MONTHNAMES.each do |month|
			next if month.blank?
			
			id += 1
			months.push([month, id])
		end
		
		years = []
		(2010..Date.today.year).each {|year| years.push([year, year]) }

		html = content_tag(:span, "View graph for")
		html << image_tag("loading.gif", :size => "20x20", :id => "historyimg") 
		html << link_to("Every Month", "#alltime", :class => "togglefocus", :id => "log_picker_all")
		html << " or "
		html << select_tag(:log_picker_month, options_for_select(months, Date.today.month))
		html << select_tag(:log_picker_year, options_for_select(years, Date.today.year))
		return html
	end
	
	def teammate_names(team)
		return Rails.cache.fetch("team/names/#{team.id}", :raw => true, :expires_in => 24.hours) do
			total_chars = team.is_random ? 1 : team.bracket
			added_chars = 0
			names = ""
			
			team.characters.each do |character|
				added_chars += 1
				
				names << ", " if added_chars < total_chars && added_chars > 1
				names << " and " if added_chars == total_chars && total_chars > 1
				names << character.full_name
			end
			names
		end
	end
	
	def build_team_graph(team)
		history = team.build_history(30.days.ago.utc)
		return javascript_tag("var team_id = #{team.id}; var points_data = #{history[:points].to_json};\n var ranks_data = #{history[:ranks].to_json};")
	end
	
	def history_text(history, last_history)
		if last_history.nil?
			text = "#{history[:points]} points"
		elsif last_history[:league] > history[:league]
			text = "#{history[:points]} points (demoted to #{LEAGUES[history[:league]]})"
		elsif last_history[:league] < history[:league]
			text = "#{history[:points]} points (promoted to #{LEAGUES[history[:league]]})"
		elsif last_history[:points] > history[:points]
			text = "#{history[:points]} points (lost #{last_history[:points] - history[:points]} points)"
		elsif last_history[:points] < history[:points]
			text = "#{history[:points]} points (gained #{history[:points] - last_history[:points]} points)"
		else
			text = "#{history[:points]} points"
		end
		
		return text if history.nil? || last_history.nil? || history[:world_rank].nil?
		
		if last_history[:world_rank].nil? || history[:world_rank] == last_history[:world_rank]
			text << ", #{history[:world_rank]} world rank"
		elsif last_history[:world_rank] > history[:world_rank]
			text << ", #{history[:world_rank]} world rank (rank #{history[:world_rank] - last_history[:world_rank]} places)"
		elsif last_history[:world_rank] < history[:world_rank]
			text << ", #{history[:world_rank]} world rank (rank +#{history[:world_rank] - last_history[:world_rank]} places)"
		end
		
		return text
	end
	
	def build_history(team)
		html = []
		
		records = []
	
		# Grab it in newest -> oldest order
		team.histories.all(:select => "*", :joins => "JOIN team_history_periods ON (team_histories.id >= team_history_periods.starts_at AND team_histories.id <= team_history_periods.ends_at)", :order => "team_history_periods.created_at ASC", :limit => 10).each do |history|
			records.push(history)
		end

		if records.length == 0
			return content_tag(:tr, content_tag(:td, "No history has been saved yet."), :class => "darkbg")
		end
		
		# Flip it to oldest -> newest so we can figure out filtering
		records.reverse!
		final_list = []
		
		last_id = nil
		last_history = nil
		records.each do |history|
			last_id = history.id
			next if last_history && last_history.world_rank == history.world_rank && last_history.points == history.points && last_history.league == history.league
			last_history = history
			
			final_list.push(:world_rank => history.world_rank, :points => history.points, :league => history.league, :created_at => Time.parse(history.created_at), :id => history.id)
		end
		
		records = final_list
		
		# Now take the final flipped list with duplicates pruned out and create magic
		last_history = nil
		records.each do |history|
			#history_html = content_tag(:td, "#{image_tag("#{LEAGUES[history.league]}-small.png", :size => "20x22")} #{content_tag(:span, LEAGUE_NAMES[history.league])}", :class => "league")
			history_html = content_tag(:td, image_tag("#{LEAGUES[history[:league]]}-small.png", :size => "20x22"), :class => "league")
			
			points = wrap_number(number_with_delimiter(history[:points]))
			# No history yet
			if last_history.nil?
				history_html << content_tag(:td, "#{points} points", :class => "points")
			# Demoted
			elsif last_history[:league] > history[:league]
				history_html << content_tag(:td, "%s points (%s)" % [points, content_tag(:span, "demoted", :class => "red")], :class => "points")
			# Promoted
			elsif last_history[:league] < history[:league]
				history_html << content_tag(:td, "%s points (%s)" % [points, content_tag(:span, "promoted", :class => "green")], :class => "points")
			# Lost points
			elsif last_history[:points] > history[:points]
				history_html << content_tag(:td, "%s points (%s)" % [points, content_tag(:span, number_with_delimiter(history[:points] - last_history[:points]), :class => "red")], :class => "points")
			# Gained points 
			elsif last_history[:points] < history[:points]
				history_html << content_tag(:td, "%s points (%s)" % [points, content_tag(:span, "+#{number_with_delimiter(history[:points] - last_history[:points])}", :class => "green")], :class => "points")
			else
				history_html << content_tag(:td, "%s points" % [points], :class => "points")
			end
			
			# No world rank period
			if history[:world_rank].nil?
				history_html << content_tag(:td, "&nbsp;", :class => "world")
			# No world rank yet, or no previous one to compare
			elsif last_history.nil? || last_history[:world_rank].nil? || history[:world_rank] == last_history[:world_rank]
				history_html << content_tag(:td, "#{wrap_number("#%s")} world" % [number_with_delimiter(history[:world_rank])], :class => "world")
			# Gained rank
			elsif last_history[:world_rank] > history[:world_rank]
				history_html << content_tag(:td, "#{wrap_number("#%s")} world (%s)" % [number_with_delimiter(history[:world_rank]), content_tag(:span, "+#{number_with_delimiter(last_history[:world_rank] - history[:world_rank])}", :class => "green") ], :class => "world")
			# Lost rank
			elsif last_history[:world_rank] < history[:world_rank]
				history_html << content_tag(:td, "#{wrap_number("#%s")} world (%s)" % [number_with_delimiter(history[:world_rank]), content_tag(:span, "-#{number_with_delimiter(history[:world_rank] - last_history[:world_rank])}", :class => "red")], :class => "world")
			end
						
			history_html << content_tag(:td, history[:created_at], :class => "jstime #{history[:created_at].utc.to_i}")
			
			html.push(content_tag(:tr, history_html, :class => cycle("darkbg", "lightbg")))
			last_history = history
		end
		
		# Finally, flip it back so it's newest -> oldest, take the last 5 and we're done
		return html.reverse[0, 5].join
	end
end
