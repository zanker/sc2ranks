module FeedsHelper
	def feed_replay_players(replay)
		html = ""
		if replay.bracket == "ffa" 
			replay.replay_characters.each do |relation|
				next if relation.character.nil?
				
				html << relation.character.full_name << " (#{RACE_NAMES[relation.played_race]}), "
			end
			
			html = html[0..-3]
		else
			teams = {}
			replay.replay_characters.each do |relation|
				character = relation.character
				next if character.nil?
				
				teams[relation.team_id.to_i] ||= ""
				teams[relation.team_id.to_i] << character.full_name << " (#{RACE_NAMES[relation.played_race]}), "
			end
			
			teams.keys.sort.each do |team_id|
				html << teams[team_id][0..-3] << " VS "
			end
			
			html = html[0..-4]
		end
		
		return html
	end
	
	def feed_replay_name(replay)
		return "#{replay.map.name}, #{replay.bracket.match(/([0-9]+)/) ? replay.bracket : replay.bracket.upcase}"
	end
	
	def feed_map_name(match)
		bracket_name = match.bracket == HISTORY_BRACKETS["ffa"] && "FFA" || match.bracket == HISTORY_BRACKETS["custom"] && "Custom" || match.bracket == HISTORY_BRACKETS["co_op"] && "Co-op" || "#{match.bracket}v#{match.bracket}"

		if match.points != 0
			return "%s - %s, %s (%s points)" % [match.map.name, HISTORY_RESULT_FEED_NAMES[match.results], bracket_name, (match.points > 0 ? "+#{match.points}" : match.points)]
		end
		
		return "%s - %s, %s" % [match.map.name, HISTORY_RESULT_FEED_NAMES[match.results], bracket_name, HISTORY_RESULT_NAMES[match.results]]
	end
end
