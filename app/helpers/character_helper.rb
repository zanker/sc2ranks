module CharacterHelper
	def replay_bracket(bracket)
		return bracket.match(/([0-9]+)/) ? bracket : bracket.upcase
	end
	
	def replay_sites(replays)
		sites = {}
		replays.each do |replay|
			sites[replay.replay_site_id] = replay.site
		end
		
		html = ""
		sites.each do |site_id, site|
			html << link_to(site.name, site.url) << ", "
		end
		
		unless html == ""
			html = content_tag(:div, "Source#{sites.length == 1 ? "" : "s"}: #{html[0..-3]}", :class => "replaysites")
		end
		
		return html
	end
	
	def build_player(character, name, id, race)
		if id and id > 0 and character
			text = ""
			text = image_tag("#{RACES[race]}.png", :class => RACES[race]) if race
			return text << link_to_unless_current(character.full_name, character_path(character.region, character.bnet_id, character.name))
		else
			return content_tag(:span, name, :class => :nolink)
		end
	end
	
	def vod_players(vod)
		html = ""
		html << content_tag(:td, build_player(vod.player_one_char, vod.player_one, vod.player_one_id, vod.player_one_race), :class => :players)
		html << content_tag(:td, build_player(vod.player_two_char, vod.player_two, vod.player_two_id, vod.player_two_race), :class => :players)
		
		return html
	end
	
	def replay_players(replay)
		html = ""
		if replay.bracket == "ffa" 
			replay.replay_characters.each do |relation|
				character = relation.character
				next if character.nil?

				html << image_tag("#{RACES[relation.played_race]}.png", :class => RACES[relation.played_race]) << link_to_unless_current(character.full_name, character_path(character.region, character.bnet_id, character.name)) << ", "
			end
			
			html = content_tag(:td, html[0..-3], :colspan => 2, :class => :players)
		else
			teams = {}
			replay.replay_characters.each do |relation|
				character = relation.character
				next if character.nil?
				
				teams[relation.side_id] ||= ""
				teams[relation.side_id] << image_tag("#{RACES[relation.played_race]}.png", :class => RACES[relation.played_race]) << link_to_unless_current(character.full_name, character_path(character.region, character.bnet_id, character.name)) << ", "
			end
			
			other_side = nil
			if teams.length != ( replay.bracket.to_i * 2 ) 
				other_side = teams[1] && 2 || 1
				teams[other_side] = content_tag(:span, "Computer", :class => "nolink")
			end
			
			if teams.length == 2
				team_keys = teams.keys.sort
				html = content_tag(:td, teams[team_keys.first][0..-3], :class => :players) << content_tag(:td, teams[team_keys.last][0..-3], :class => :players)
			else
				teams.keys.sort.each do |side_id|
					html << teams[side_id][0..-3] unless side_id == other_side
				end
				
				html = content_tag(:td, html, :colspan => 2, :class => :players)
			end
		end
		
		return html
	end
	
	def build_map_stats(summary)
		html = ""
		
		HISTORY_BRACKET_ORDER.each do |bracket|
			map_stats = summary[bracket]
			next unless map_stats
			
			points = map_stats[:points] > 0 && content_tag(:span, "+#{map_stats[:points]}", :class => "green") || map_stats[:points] == 0 && content_tag(:span, "0", :class => "number") || content_tag(:span, map_stats[:points], :class => "red")
			
			
			row_sums = content_tag(:td, "Total points: #{points}") << content_tag(:td, "Total games: #{wrap_number(map_stats[:total])}")

			USED_HISTORY_RESULTS.each do |id|
				results = map_stats[:results][id]
				total = results && results[:total] || 0
				
				row_sums << content_tag(:td, "%s: %s (%.1f%%)" % [HISTORY_RESULT_FEED_NAMES[id], wrap_number(number_with_delimiter(total)), ((map_stats[:total] > 0 ? total / map_stats[:total].to_f : 0) * 100)])
			end
			
			html_sum = ""
			html_sum << content_tag(:tr, content_tag(:th, HISTORY_BRACKET_NAMES[bracket], :colspan => 6, :class => ""))
			html_sum << content_tag(:tr, row_sums, :class => "lightbg")
			
			html << content_tag(:div, "", :class => "spacer")
			html << content_tag(:div, content_tag(:table, html_sum, :cellspacing => "1px", :class => "shadow"), :class => "w960 mapsum")
		end

		return html
	end
	
	def match_bracket(match)
		if match.bracket == HISTORY_BRACKETS["ffa"]
			return "FFA"
		elsif match.bracket == HISTORY_BRACKETS["custom"]
			return "Custom"
		elsif match.bracket == HISTORY_BRACKETS["co_op"]
			return "Co-op"
		else
			return wrap_number("#{match.bracket}v#{match.bracket}")
		end
	end
	
	def match_points(match)
		return "---" if match.points == 0
		return match.points > 0 ? content_tag(:span, "+#{match.points}", :class => "green") : content_tag(:span, match.points, :class => "red")
	end

	def match_results(match)
		return "#{content_tag(:span, HISTORY_RESULT_NAMES[match.results], :class => "match-#{HISTORY_RESULTS[match.results]}")}"
	end
	
	def error_message(error)
		if error.error_type == "noCharacter"
			return "No character found, either you entered the URL wrong or the character does not exist."
		elsif error.error_type == "maintenance"
			return "Blizzard's armory is under maintenance right now, please try again later."
		elsif error.error_type == "error"
			return "A generic error was found, please report this."
		end

		return "Unknown code #{error.error_type}, please report this."
	end
	
	def wrap_number(text)
		return content_tag(:span, text, :class => "number")
	end

	def build_team(team, team_row, total_teams)
		background = cycle("lightbg", "darkbg")
		bottomborder = team_row < total_teams && " bottomborder" || ""
		topborder = team_row == 1 && " topborder" || ""
		
		# Add the league in a nice giant icon to show off your e-penis size
		top_tr = content_tag(:td, team_badge(team, "medium"), :class => "badge#{topborder}#{bottomborder}", :rowspan => 2)
		bottom_tr = ""
		
		# Add the teams link
		if team.bracket == 1
			top_tr << content_tag(:td, link_to("More details", team_path(team.id)), :class => "history#{topborder} history1", :rowspan => 2)
		else
			top_tr << content_tag(:td, team[:is_random] ? "Random" : "Team", :class => "bracket#{topborder}")
			bottom_tr << content_tag(:td, link_to("More details", team_path(team.id)), :class => "history historyall")
		end
		
		# Region rankings
		if team.points > 0
			small_league = team_badge(team, "22x23")
			top_tr << content_tag(:td, "#{small_league}" << content_tag(:div, "World: #{wrap_number("#%s")}" % [number_with_delimiter(team.world_rank)]), :class => "worldrank#{topborder}")
			bottom_tr << content_tag(:td, "#{small_league}" << content_tag(:div, "Region: #{wrap_number("#%s")}" % [number_with_delimiter(team.region_rank)]), :class => "regionrank")
		else
			top_tr << content_tag(:td, "World: ---", :class => "worldrank#{topborder}")
			bottom_tr << content_tag(:td, "Region: ---", :class => "regionrank")
		end
		
		# Add the summary info
		if team.losses == 0
			top_tr << content_tag(:td, "#{wrap_number("%s")} points, won #{content_tag(:span, "%s", :class => "green")}" % [number_with_delimiter(team.points), number_with_delimiter(team.wins)], :class => "summary#{topborder}", :colspan => 2)
		else
			total_games = team.wins + team.losses
			ratio = total_games > 0 ? team.wins.to_f / total_games : 0
			top_tr << content_tag(:td, "#{wrap_number("%s")} points. Won #{content_tag(:span, "%s", :class => "green")}, lost #{content_tag(:span, "%s", :class => "red")} (%.2f%% wins)" % [number_with_delimiter(team.points), number_with_delimiter(team.wins), number_with_delimiter(team.losses), ratio * 100], :class => "summary#{topborder}", :colspan => 2)
		end

		# Add the rank in division
		top_tr << content_tag(:td, "Rank #{wrap_number("%d")} of #{can_link_to("%s", rank_division_path(team.division.id, parameterize(team.division.name)))}" % [team.division_rank, team.division.name], :class => "divisionrank#{topborder}", :colspan => 2)
		
		# Add characters
		added_characters = 0
		team.team_characters.each do |relation|
			character = relation.character
			
			if character.nil?
				bottom_tr << content_tag(:td, "&nbsp;", :class => "character")
			else
				bottom_tr << content_tag(:td, image_tag("#{RACES[relation.played_race]}.png", :class => RACES[relation.played_race]) << can_link_to_unless(character.full_name, character_path(character.region, character.bnet_id, character.name)), :class => "character")
			end
			
			added_characters += 1
		end
		
		# Add filler characters
		(added_characters...4).each do |i|
			bottom_tr << content_tag(:td, "&nbsp;", :class => "character")
		end
		
		return content_tag(:tr, top_tr, :class => background) << content_tag(:tr, bottom_tr, :class => "#{background}#{bottomborder}")
	end

	def build_full_teams(teams)
		html = ""

		brackets = {}
		teams.each do |team|
			next if team.division.nil?
			brackets[team.expansion] ||= {}			

			brackets[team.expansion][team.bracket] ||= []
			brackets[team.expansion][team.bracket].push(team)
		end
	
		EXPANSIONS.keys.sort.reverse.each do |expansion|
			(1...5).each do |bracket|
				next unless brackets[expansion]				

				teams = brackets[expansion][bracket]
				next unless teams && teams.length > 0
			
				reset_cycle()
				teams.sort!{|a, b| a.points <=> b.points }
			
				# Create the bracket container now
				newest_team = nil
				teams.each do |team|
					newest_team = team.division.updated_at if newest_team.nil? || team.division.updated_at > newest_team
				end

				# Do the toggles
				header_ths = content_tag(:th, "-", :class => "toggleclick", :id => "#{bracket}ptogg")
			
				# Do the main header
				header = content_tag(:span, "#{bracket} vs #{bracket} - #{EXPANSIONS[expansion]}", :class => "headertext")
				header << content_tag(:span, "updated #{content_tag(:span, "", :class => "jstime #{newest_team.to_i}")}", :class => "headerupdated")
				header_ths << content_tag(:th, header, :colspan => 8)
			
				bracket_html = content_tag(:tr, header_ths)
			
				team_row = 0
				teams.each do |team|
					team_row += 1
					bracket_html << build_team(team, team_row, teams.length)
				end
			
				# And wrap it up
				html << content_tag(:div, "", :class => "spacer")
				html << content_tag(:div, content_tag(:table, bracket_html, :cellspacing => "1px", :class => "shadow"), :class => "w960 leagues")
			end
		end
		
		return html
	end
end
