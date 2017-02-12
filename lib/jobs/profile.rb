require "nokogiri"
require "uri"
require "cgi"

module Jobs
	class Profile
		# http://eu.battle.net/sc2/en/profile/212473/1/PoseidonII/
		def self.get_url(args)
			return "parse", ["profile", args[:bnet_id], LOCALE_IDS[args[:region]], URI.escape(args[:name]), "ladder", "leagues"]
		end
		
		def self.increment_retries(character)
			character.retries ||= 0
			character.retries += 1
			
			# At 3 failures, will find two teams they were in and pull characters
			if character.retries == 3
				character.teams.all(:order => "updated_at DESC", :limit => 2).each do |team|
					puts "Trying to find character off of team"
					puts team.to_json
					
					# Find another team from the same division we can use
					locate_team = Team.first(:conditions => ["id != ? AND teams.division_id = ?", team.id, team.division_id], :order => "updated_at DESC", :include => :first_character)
					next unless locate_team && locate_team.first_character
					
					Armory::Queue.division(:region => character.region, :char_bnet_id => character.bnet_id, :char_name => character.name, :bnet_id => locate_team.division.bnet_id, :is_auto => true, :force => true, :tag => 91)
				end
			# Kill records if we hit the limit
			elsif character.retries == 10
				Notifier.deliver_alert("Retry limit hit #{character.name}", character.to_json)

				character.destroy
				TeamCharacter.delete_all(["character_id IN (?)", character_ids])
				return
			end
			
			character.save
		end
		
		def self.save_character(character, doc, raw_html)
			# Changed to:
			#<h2><a href="/sc2/en/profile/715900/1/dayvie/">dayvie<span>#947</span></a></h2>
			profile_doc = doc.xpath("//div[@id='profile-header']/h2/a/span")
			character_code = 0
			if profile_doc && profile_doc.text().match(/[0-9]+/)
				character_code = profile_doc.text().match(/([0-9]+)/)[1].to_i
			end
			
			achievement_doc = doc.xpath("//div[@id='profile-header']/h3")
			if achievement_doc
				character.achievement_points = achievement_doc.text().to_i || 0
			end

			tag_doc = doc.css("#profile-header .clan-tag")
			tag = nil
			if tag_doc
				tag = tag_doc.text.tr("[]", "")
			end
			

			name_doc = doc.css("#profile-header .user-name a")
			name = nil
			if name_doc
				name = name_doc.text.strip
			end

			# Name change
			if ( character.name && name != character.name ) || ( tag != character.tag )
				NameChange.create(:old_name => character.name, :new_name => name, :character_id => character.id, :old_tag => character.tag, :new_tag => tag)
			end
						
			portrait_doc = doc.xpath("//div[@id='portrait']").inner_html()
			unless portrait_doc.blank?
				icon_id = portrait_doc.match(/portraits\/([0-9]+)-([0-9]+)\.jpg/)
				sprite_loc = portrait_doc.match(/\) (-[0-9]+|[0-9]+)px (-[0-9]+|[0-9]+)px/s)

				if icon_id && sprite_loc
					image_size = icon_id[2].to_i
					icon_x = sprite_loc[1].to_i
					icon_y = sprite_loc[2].to_i
					
					portrait_id = Portrait.id_from_sprite(icon_id[1].to_i, icon_x, icon_y, image_size)

					# Create an entry for it if we need to
					unless Rails.cache.read("portrait/#{portrait_id}", :raw => true, :expires_in => 24.hours)
						portrait = Portrait.first(:conditions => {:portrait_id => portrait_id})
						unless portrait
							portrait = Portrait.new
							portrait.portrait_id = portrait_id
							portrait.icon_id = icon_id[1].to_i
							portrait.icon_row = Portrait.row_from_y(icon_y, image_size)
							portrait.icon_column = Portrait.column_from_x(icon_x, image_size)
							portrait.save
						end
						
						Rails.cache.write("portrait/#{portrait_id}", "1", :raw => true, :expires_in => 24.hours)
					end
					
					# Save to character
					character.portrait_id = portrait_id
				end
			end
			
			character.name = name if name && !name.blank?
			character.tag = tag && !tag.blank? ? tag : nil
			character.lower_name = name.downcase if name && !name.blank?
			character.character_code = character_code if character.character_code.nil? || character_code > 0
			character.retries = nil
			character.touch
		end
		
		def self.parse_match_history(character, doc, raw_html)
			match_history = []
			
			id = 0
			doc.xpath("//tr[starts-with(@class, 'match-row')]").each do |match_doc|
				columns = match_doc.css("td")
				next unless columns.length == 5
				
				map_name = columns[1].text.strip
				bracket_type =  match_doc.attr("class").match(/solo|twos|threes|fours|ffa|co_op|custom/).to_s
				type = columns[3].inner_html.match(/win|loss|watcher|tie|undecided|bailer|disagree/).to_s
				points = columns[3].inner_html.match(/\-[0-9]+|\+[0-9]+/).to_s.to_i
				date = CharacterAchievement.translate_date(columns[4].text.strip, character.region)
							
				next if map_name.blank? || type.blank? || date.blank? || bracket_type.blank?
				
				# Heres where we do various voodoo magic to get around crazy localization issues
				
				# If we didn't find a bracket it's FFA or Custom, if we found a points gained/lost it's FFA, otherwise it's custom
				#if bracket == 0
				#	bracket_type = columns[3].inner_html.match(/text-green|text-red/).nil? ? "custom" : "ffa"
				#end
				
				map_id = (Rails.cache.fetch(Digest::SHA1.hexdigest("map/id/#{character.region}/#{map_name}"), :raw => true, :expires_in => 24.hours) do
					map = Map.first(:conditions => {:region => character.rank_region, :name => map_name}) || Map.new(:region => character.rank_region, :name => map_name)
					# Try and convert it into the US map name for statistics
					map.name_id = MAP_LOCALIZATIONS[map_name] || map_name
					map.is_blizzard = ( BLIZZARD_MAPS[map.name_id] || bracket_type == "solo" || bracket_type == "twos" || bracket_type == "threes" || bracket_type == "fours" ) ? true : false
					map.last_game = Time.now.utc
					map.save
					
					# Create the initial null stat_date that holds total games
					unless MatchTotal.exists?(["map_id = ? AND stat_date IS NULL", map.id])
						map.stats.create(:map_id => map.id)
					end					

					map.id
				end).to_i
				
				next if map_id == -1
												
				# Convert bracket into a single id
				bracket = bracket_type == "solo" && 1 || bracket_type == "twos" && 2 || bracket_type == "threes" && 3 || bracket_type == "fours" && 4 || HISTORY_BRACKETS[bracket_type] || HISTORY_BRACKETS["unknown"]
				# Convert type into a single id
				type = HISTORY_RESULTS[type] || HISTORY_RESULTS["unknown"]
				
				id += 1
				history = {:map_id => map_id, :bracket => bracket, :results => type, :points => points, :played_on => date, :id => id, :hash_id => "#{map_id}/#{bracket}/#{type}/#{points}/#{date.to_i}"}
				match_history.push(history)
			end
			
			cached_matches = []
			character.matches.all(:order => "id DESC", :limit => match_history.length).each do |match|
				match[:hash_id] = "#{match.map_id}/#{match.bracket}/#{match.results}/#{match.points}/#{match.played_on.to_i}"
				cached_matches.push(match)
			end
			
			if cached_matches.length > 0
				# Going to have to figure out some voodoo to clean this up
				# go through each match history, then go through the cache  and figure out where in the cache the next two records match
				# two records matching means will assume that we found the offset where the maps left off and we can prune records after that
				offset = nil
				match_history.each_index do |id|
					live_match = match_history[id]
				
					cached_matches.each_index do |cached_id|
						cached_match = cached_matches[cached_id]
						if live_match[:hash_id] == cached_match[:hash_id]
							matches = 0
							3.times do |check_id|
								next_live_match = match_history[id + check_id]
								next_cached_match = cached_matches[cached_id + check_id]
								if next_live_match && next_cached_match && next_live_match[:hash_id] == next_cached_match[:hash_id]
									matches += 1
								end
							end
							
							if matches == 3
								offset = id
								break
							end
						end
					end
					
					break if offset
				end
				
				# Clean off any records if we need to
				match_history.slice!(offset, match_history.length - offset) if offset
			end
			
			match_history.reverse!.each do |match|
				match.delete(:hash_id)
				match.delete(:id)

				character.matches.create(match)
				
				# Check if we need to add a stat entry for this day
				Rails.cache.fetch("map/stats/date/#{match[:map_id]}/#{match[:played_on].to_i}", :raw => true, :expires_in => 24.hours) do
					unless MatchTotal.exists?(:map_id => match[:map_id], :stat_date => match[:played_on])
						MatchTotal.create(:map_id => match[:map_id], :stat_date => match[:played_on])
					end					
				end
			end
		end
		
		# This is technically a bit inefficient, we could immediately dispatch one league query without resending it, but for sanity
		# I am going to break them up for the time being
		def self.parse(args, doc, raw_html)
			# Load division info
			valid_divisions = {}
			divisions = []	
			
			doc.xpath("//a[starts-with(@data-tooltip, '#menu-team')]").each do |link_doc|
				division_id = link_doc.attr("data-tooltip").to_s.match(/menu\-team\-([0-9]+)/)[1].to_i
				bracket = link_doc.text.strip().match(/([0-9]+)/)[1].to_i
				
				next if division_id == 0 || bracket == 0 || args[:skip_division] && args[:skip_division] == division_id
				
				valid_divisions[division_id] = bracket
			end
				
			doc.xpath("//div[starts-with(@id, 'menu-team')]").each do |team_doc|
				division_id = team_doc["id"].match(/([0-9]+)/)[0].to_i
				team_members = team_doc.xpath("div").first().inner_html()
				# Count commas, add one for the last person in it
				# This makes sure we don't record random divisions
				members = team_members.scan(/,/).length + 1
				
				next unless valid_divisions[division_id] && !team_members.blank?
				divisions.push(division_id)
			end
			
			# It's possible for a character to be in the same division twice, eg
			# http://us.battle.net/sc2/en/profile/1468/2/kzspygv/ladder/1953#current-rank
			divisions.uniq!
						
			# Now create the character or update it
			character = Character.first(:conditions => {:bnet_id => args[:bnet_id], :region => args[:region]}) 
			is_new = true unless character
									
			character ||= Character.new
			character.region = args[:region].downcase
			character.rank_region = RANK_REGIONS[character.region]
			character.bnet_id = args[:bnet_id]
			character.name = args[:name]
			character.lower_name = args[:name].downcase
			character.total_teams = divisions.length
			character.character_code = args[:character_code].to_i unless args[:character_code].blank? or args[:character_code] <= 0
						
			save_character(character, doc, raw_html)
			
			# Pull match history
			begin
				cat_response, url = Armory::Node.pull_custom_data(args[:region], ["profile", args[:bnet_id], LOCALE_IDS[args[:region]], URI.escape(args[:name]), "matches"])
				cat_doc = Nokogiri::HTML(cat_response)
				
				unless cat_response.blank? && cat_doc.blank?
					self.parse_match_history(character, cat_doc, cat_response)
				end
			rescue EOFError, OpenURI::HTTPError => e
				puts "#{e.class}: #{e.message}"
			end
			
			return unless args[:no_cascade].blank?
			
			# The reason we queue the division here is mostly safety to prevent the once in a million chance that a division is processed before
			# the character would be saved
			divisions.each do |division_id|
				Armory::Queue.division(:region => args[:region], :char_bnet_id => args[:bnet_id], :char_name => args[:name], :bnet_id => division_id, :is_auto => args[:is_auto], :force => args[:force], :tag => 92)
			end
		end
	end
end
