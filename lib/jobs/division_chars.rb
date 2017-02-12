require "nokogiri"
require "uri"

module Jobs
	class DivisionChars
		# http://eu.battle.net/sc2/en/profile/212473/1/PoseidonII/ladder/1345/#current-rank
		# http://tw.battle.net/sc2/zh/profile/33433/2/Ryan/ladder/leagues#current-rank
		# The 2 is used as some sort of sub-region, for example /2/ in EU is Russia, /2/ in US is South America
		def self.get_url(args)
			#url = ["profile", args[:char_bnet_id], LOCALE_IDS[args[:region]], URI.escape(args[:char_name]), "ladder", (args[:league] == LEAGUES["grandmaster"] && "grandmaster" || args[:bnet_id])]
			url = ["profile", args[:char_bnet_id], LOCALE_IDS[args[:region]], URI.escape(args[:char_name]), "ladder", args[:bnet_id]]
			return "parse", url
		end
	
		def self.parse(args, doc, raw_html)
			if doc.nil?
				Armory::Worker.say "Nil HTML returned on worker"
				return
			end	
			
			debug = false
			start_time = Time.now.to_f if debug
			
			# Grab character
			character = Character.first(:conditions => {:region => args[:region], :bnet_id => args[:char_bnet_id]})
			if character
				Jobs::Profile.save_character(character, doc, raw_html)
			end
			
			data = doc.xpath("//div[starts-with(@class, 'data-label')]/h3").first
			return "nodata" if data.nil?
			
			data = data.inner_html().split("</span>", 2)
			return "nodata" if data.nil?
			
		
			expansions = [nil] + EXPANSIONS.keys.sort.reverse	

			exp_level = nil
			doc.xpath("//ul[@id='profile-menu']/li").each do |row|
				html = row.inner_html
				# It's the team we want, log the expansion level
				if html =~ /menu\-team\-#{args[:bnet_id]}/
					exp_level = expansions.first
					break
				# It's an Expansion header, so shift to the proper expansion level
				elsif html !~ /\/sc2\// and html !~ /menu\-team/
					expansions.shift
				end
			end
		
			return "noexp" unless exp_level
			puts "Expansion level #{exp_level} - #{EXPANSIONS[exp_level]}" if debug
			division = Division.first(:conditions => {:bnet_id => args[:bnet_id], :region => RANK_REGIONS[args[:region].downcase]})

			# For non-US locales
			#data[0].gsub!(/&#([0-9]+);/, "")
                        data[0] = data[0].gsub("\t", "").gsub("\r", "").gsub("\n", "")
                        puts data[0].inspect if debug
                        year = data[0].strip.match(/^([0-9]{4})/)
                        season = data[0].strip.match(/#{year}.+([0-9]{1,3}) \</)

			puts "#{data[0]}, #{year}, #{season}" if debug	
			return "nodata" if season.nil? or year.nil?
			season = season[1].to_i
			year = year[1].to_i

			puts "Year #{year}, Season #{season}" if debug
			# Season when they made this change was 10 (2012), so 2012 - 2010 = 2
			# -1 = 1, which gives us 1 * 5 + 5.
			# In 2013, it'll be 2, so 10 + 1, giving us 1 and so on
			year = (year - 2012)
			season = 5 + (year * 5) + season
			puts "Current season #{season}" if debug
		
			puts "Season #{season}" if debug
	
			Rails.cache.write("season/#{RANK_REGIONS[args[:region].downcase]}", season, :raw => true, :expires_in => 1.day)
			
			# If we can't find the bracket, it means they aren't in it anymore
			# which means we need to queue them and check what they are now
			if args[:league] == LEAGUES["grandmaster"]
				bracket = 1
			else
				bracket = data[1].match(/(1|2|3|4|5).(1|2|3|4|5)/)
				if bracket.nil?
					if character
						Armory::Queue.character(:region => character.region, :is_auto => true, :bnet_id => character.bnet_id, :name => character.name, :bracket => true, :tag => 1, :priority => 10)
					end
				
					Armory::Worker.say "Bad bracket #{character.region}"
					return "badbracket" if bracket.nil?
				end
			
				bracket = bracket[1].to_i
			end
			
			return "badconversion" if bracket == 0
			
			bonus_pool = 0
			pool = doc.xpath("//span[@id='bonus-pool']/span")
			if pool
				bonus_pool = pool.text().to_i
			end
			
			# Parse out every team
			team_data = []
			character_list = {}
			character_names = {}
			character_ids = {}
			
			min_points, max_points, total_points, total_wins, total_games = 5000000, 0, 0, 0, 0
			
			ranking_doc = doc.xpath("//table[@class='data-table ladder-table']").first
			return "noranks" if ranking_doc.nil?
			
			is_random = true

			ranking_doc.xpath("//tbody/tr").each do |rank_doc|
				columns = rank_doc.xpath("td")
				start_at = (columns[0].attr("class").match(/banner/) ? 1 : 0)
				
				joined = columns[start_at].attr("data-tooltip")
				joined = joined && joined.match(/([0-9]+\/[0-9]+\/[0-9]+)/)
				joined = joined && joined[1] || nil
				rank = columns[start_at + 1].text.match(/([0-9]+)/)[1].to_i
				points = columns[columns.length - 3].text.to_i
				wins = columns[columns.length - 2].text.to_i
				losses = columns[columns.length - 1].text.to_i
				
				offset = 3
				if columns[columns.length - 3].attr("class").nil?
					points = wins
					wins = losses
					losses = 0
					offset = 2
				end
				
				next if rank == 0
				
				consumed_pool = nil
				team_characters = {}
				race_comp = []
				team_region = nil
				
				# Loop through the characters, the last 3 are ranking/win/lose info
				columns.each do |column|
					next unless column.attr("class").nil?
					
					character_doc = column.xpath("a")
					next if character_doc.nil? || character_doc.attr("class").to_s.blank?
					
					#/sc2/zh/profile/35964/2/Stupidbbq/
					match = character_doc.attr("href").to_s.match(/sc2\/.+\/profile\/([0-9]+)\/([0-9]+)\/(.+?)\//i)
					bnet_id = match[1].to_i
					char_name = match[3]
					favorite_race = character_doc.attr("class").to_s.match(/race-([a-z]+)/)[1]
					tag = column.text.strip.match(/^\[(.+)\]/)
					tag = tag ? tag[1] : nil
	
					next unless bnet_id != 0 and favorite_race and char_name
					puts "[#{tag}] #{char_name}" if debug	
	
					region = args[:region]
					# LA characters and US characters share the same division, so figure out character region by URL
					if ( region == "us" or region == "la" )
					  region = ( match[2].to_i == 2 ? "la" : "us" )
					elsif ( region == "kr" or region == "tw" )
					  region = ( match[2].to_i == 2 ? "tw" : "kr" )
					elsif ( region == "ru" or region == "eu" ) 
					  region = ( match[2].to_i == 2 ? "ru" : "eu" )
					end
					team_region = region

					race_comp.push(RACES[favorite_race])
					character_list[bnet_id] = {:name => char_name, :region => region, :tag => tag}
					team_characters[bnet_id] = {:race => favorite_race}
					character_names[char_name] = bnet_id
					character_ids[region] ||= []
					character_ids[region].push(bnet_id)
					
					# We're updating from this teams battle.net profile, so we can figure out the consumed bonus pool
					consumed_pool = bonus_pool if bnet_id == args[:bnet_id]
				end
				
				# It's not a ranodm if we have at least one matching team
				is_random = false if team_characters.length == bracket
				
				team_games = wins + losses
				team_data.push({:rank => rank, :region => team_region, :joined => (CharacterAchievement.translate_date(joined, args[:region]) || Time.now.utc), :comp => race_comp.sort.join("/"), :points => points, :wins => wins, :losses => losses, :ratio => team_games > 0 ? wins.to_f / team_games : 0, :characters => team_characters, :bonus_pool => consumed_pool})
				
				# Now lets figure out division stats
				min_points = points if points < min_points
				max_points = points if points > max_points
				total_points += points
				total_games += wins + losses
				total_games += wins + losses
				total_wins += wins
			end		
			
		
			puts "---------------------" if debug
			puts "[parsing] taken #{Time.now.to_f - start_time}" if debug
								
			# Parse division info
			division ||= Division.new
                        #division_was_broken = division.bracket ? division.bracket > 5 : false
                        division.expansion = exp_level
			division.region = RANK_REGIONS[args[:region].downcase]
                        division.season = season
			division.bnet_id = args[:bnet_id]
                        division.total_teams = team_data.length
                        division.bracket = bracket
                        division.is_random = is_random if division.total_teams > 0
                        division.min_points = min_points
                        division.max_points = max_points
                        division.average_points = division.total_teams > 0 ? total_points / division.total_teams : 0
                        division.average_wins = total_games > 0 ? total_wins.to_f / total_games : 0
                        division.average_games = division.total_teams > 0 ? total_games / division.total_teams : 0
                        division.bonus_pool = bonus_pool if ( division.bonus_pool.nil? || division.bonus_pool < bonus_pool ) && bonus_pool <= 50000
                        
			allow_demote = true

                        data = doc.xpath("//div[starts-with(@class, 'data-label')]/h3/span")
                        if args[:league] == LEAGUES["grandmaster"] or data.first.text == data.last.text
                                division.league = LEAGUES["grandmaster"]
                                division.name = "Grandmaster"

                                allow_demote = (args[:league] == LEAGUES["grandmaster"])
                        else
                                division.league = LEAGUES[doc.xpath("//div[@id='menu-team-#{args[:bnet_id]}']/div/span").attr("class").to_s.match(/badge badge-([a-z]+)/)[1]]
                                division.name = data.last.text.strip()
                        end

                        puts "[creating hashes] taken #{Time.now.to_f - start_time}" if debug

                        # Create the hash id info
                        team_list = {}
                        team_data.each do |team|
                                hash_id = Digest::SHA1.hexdigest("%s,%s,%s,%s" % [team[:region], division.bracket, division.is_random, Digest::SHA1.hexdigest(team[:characters].keys.sort.to_s)])
                                team_list[hash_id] = team
                        end

                        # Found a dead division, everyone has left it, technically should never happen but just in case
                        if division.total_teams == 0
                                unless args[:block_queues]
                                        Armory::Worker.say "Found a dead division, moving everyone we had in it out of it"
                                        ActiveRecord::Base.transaction do
                                                Team.all(:conditions => ["region = ? AND teams.division_id = ?", division.region, division.id], :include => :first_character).each do |team|
                                                        next if team.first_character.nil?
                                                        Armory::Queue.character(:region => team.first_character.region, :is_auto => true, :bnet_id => team.first_character.bnet_id, :name => team.first_character.name, :bracket => true, :tag => 3, :priority => 12)
                                                end
                                        end
                                end

                                division.touch
                                return "dead"
                        end

                        puts "[dead check] taken #{Time.now.to_f - start_time}" if debug


                        # Cache all the characters
                        found_corrupted = {}

                        character_cache = {}
                        char_id_to_bnet = {}
                        character_ids.each do |region, list|
                                Character.all(:conditions => ["region = ? AND bnet_id IN (?)", region, list]).each do |character|
                                        character_cache[region] ||= {}
                                        character_cache[region][character.bnet_id] = character
                                        char_id_to_bnet[character.id] = character.bnet_id

                                        current_data = character_list[character.bnet_id]
                                        if current_data[:name] != character.name
                                                if character_names[character.name] and found_corrupted[region] == false
                                                        Armory::Worker.say "CORRUPTED: We think #{character.name} is #{current_data[:name]} (#{character.bnet_id}), but we found the name used as #{character_names[character.name]}."
                                                        # found_corrupted[region] = true
                                                end
                                        end
                                end
                        end

                        #corrupted_list.each do |char|
                        #       Armory::Queue.character(char)
                        #end
=begin          
                        # Over 5 characters, we assume the division was corrupted and will retry. Mostly a failsafe in case Blizzard rebreaks division listings again
                        # after 5 retries to requeue though, we just say screw it and let it through
                        if corrupted_characters >= (character_list.length * 0.10).ceil and ( args[:retries].nil? || args[:retries] >= 99 )
                                #if corrupted_list.length > 5
                                #       Notifier.deliver_alert("Corrupted data #{corrupted_list.length}", "#{corrupted_list.to_json}<br /><br /><br />#{Base64.encode64(raw_html)}")
                                #end

                                Armory::Worker.say "Corrupted data found for #{corrupted_characters} characters, requeuing division (try #{args[:retries].to_i})"
                                unless args[:block_queues] and ( args[:retries].nil? || args[:retries] <= 100 )
                                        Armory::Queue.division(:region => division.region, :char_bnet_id => args[:char_bnet_id], :char_name => args[:char_name], :bnet_id => args[:bnet_id], :is_auto => args[:is_auto], :force => true, :retries => (args[:retries] || 0) + 1, :tag => 93, :priority => 20)
                                end
                                return "corrupted"
                        elsif corrupted_characters > 0
                                Armory::Worker.say "Under 10% are corrupted, queuing #{corrupted_list.length} characters to find out what is what."
                                corrupted_list.each do |char|
                                        Armory::Queue.character(char)
                                end
                        end
=end

                        division.touch

                        puts "[character loads] taken #{Time.now.to_f - start_time}" if debug

                        team_cache = {}
                        team_ids = []

                        total = (Rails.cache.fetch("armory/jobs", :expires_in => 5.minutes) do
                                Armory::Job.count
                        end).to_i



                        # Save characters
                        character_list.each do |bnet_id, data|
                                begin
                                        character = character_cache[data[:region]] && character_cache[data[:region]][bnet_id] || Character.new
                                        # No entry, create one
                                        if character_cache[data[:region]] && character_cache[data[:region]][bnet_id].nil?
                                                updated_at = character.updated_at

                                                character.region = data[:region].downcase
                                                character.rank_region = RANK_REGIONS[data[:region].downcase]
                                                character.name = data[:name]
                                                character.lower_name = data[:name].downcase
                                                character.bnet_id = bnet_id
                                                character.total_teams ||= 0
                                		character.season = season
						character.tag = data[:tag]
				                character.touch

                                                if total <= 10000 and character.updated_at <= 1.week.ago
                                                        Armory::Queue.character(:region => character.region, :is_auto => true, :bnet_id => character.bnet_id, :name => character.name, :tag => 86, :priority => 20)
                                                end

                                        # Name changed, switch it over to the new one
                                        elsif character.name != data[:name] || character.tag != data[:tag]
                                                NameChange.create(:old_name => character.name, :new_name => data[:name], :character_id => character.id, :old_tag => character.tag, :new_tag => data[:tag])

                                                Armory::Worker.say "Name change, was [#{character.tag}] #{character.name} but now [#{data[:tag]}] #{data[:name]}"
                                                character.name = data[:name]
						character.tag = data[:tag]
                                                character.lower_name = data[:name].downcase
                                                character.season = season
						character.touch
                                        elsif character.season != season
						character.season = season
						character.touch
					end

                                        data[:character_id] = character.id
                                # Duplicate key, manually pull the character and try again
                                rescue ActiveRecord::StatementInvalid => e
                                        Armory::Worker.say "#{e.class}: #{e.message}"
                                        if e.message.match(/duplicate key value violates/)
                                                character_cache[data[:region]] ||= {}
                                                character_cache[data[:region]][bnet_id] = Character.first(:conditions => {:region => data[:region], :bnet_id => bnet_id})
                                                retry
                                        end
                                end
                        end

                        puts "[character checks] taken #{Time.now.to_f - start_time}" if debug

                        # Cache all the teammates
                        Team.all(:conditions => ["hash_id IN (?)", team_list.keys]).each do |team|
                                team_cache[team.hash_id] = team
                        end



			puts "[team loads] taken #{Time.now.to_f - start_time}" if debug

			# Save all the teammates
			team_list.each do |hash_id, data|
				# We changed divisions, record info for statistics
				if team_cache[hash_id] && team_cache[hash_id].league != division.league
					# Armory seems to mix up win/lose ratios sometimes, so only record if it went up or didn't change
					if data[:losses] >= team_cache[hash_id].losses && data[:wins] >= team_cache[hash_id].wins
						DivisionChanges.create(:wins => data[:wins], :losses => data[:losses], :team_id => team_cache[hash_id].id, :points => data[:points], :new_league => division.league, :old_league => team_cache[hash_id].league, :old_wins => team_cache[hash_id].wins, :old_losses => team_cache[hash_id].losses, :old_points => team_cache[hash_id].points, :created_at => Time.now.utc)
					end
				end
				
				begin
					# Check for changes so we can update last game
					has_changes = nil
					if team_cache[hash_id]
						old_data = team_cache[hash_id]
						if old_data.wins != data[:wins] || old_data.losses != data[:losses] || old_data.league != division.league || old_data.division_id != division.id || old_data.points != data[:points]
							has_changes = true
						end
					end
					
					if team_cache[hash_id] and team_cache[hash_id].season and team_cache[hash_id].season < division.season
						team = team_cache[hash_id]
						TeamSeason.create(:team_id => team.id, :region => team.region, :points => team.points, :wins => team.wins, :losses => team.losses, :win_ratio => team.win_ratio, :league => team.league, :bracket => team.bracket, :race_comp => team.race_comp, :is_random => is_random, :bonus_pool => team.bonus_pool, :world_rank => team.world_rank, :region_rank => team.region_rank, :season => team_cache[hash_id].season)
						puts "Shifted team data into the season table for #{team.id}, #{division.season}, #{team_cache[hash_id].season}" if debug
					end

					team = team_cache[hash_id] || Team.new
					team.season = division.season
					team.expansion = division.expansion
					team.hash_id = hash_id
					team.region = division.region
					team.points = data[:points]
					team.wins = data[:wins]
					team.losses = data[:losses]
					team.win_ratio = ((data[:ratio] * 10000) + 0.5).floor.to_f / 10000
					team.race_comp = data[:comp]
					team.division_rank = data[:rank]
					team.division_id = division.id
					team.is_random = is_random
					team.league = division.league
					team.bracket = division.bracket
					team.joined_league = data[:joined]
					team.last_game_at = Time.now.utc if team.last_game_at.nil? || has_changes
					team.bonus_pool = data[:bonus_pool] unless data[:bonus_pool].nil?

					team.save
					team_ids.push(team.id)

					data[:characters].each do |bnet_id, char_data|
						char_data[:team_id] = team.id
					end
				rescue ActiveRecord::StatementInvalid => e
					Armory::Worker.say "#{e.class}: #{e.message}"
					if e.message.match(/duplicate key value violates/)
						team_cache[hash_id] = Team.first(:conditions => {:region => division.region, :hash_id => hash_id})
						retry
					end
				end
			end
			
			#if team_ids.length > 0
			#	Team.update_all(["updated_at = ?", Time.now.utc], ["id IN (?)", team_ids])
			#end
			
			puts "[team checks] taken #{Time.now.to_f - start_time}" if debug

			relation_cache = {}
			TeamCharacter.all(:conditions => ["team_id IN (?)", team_ids]).each do |relation|
				relation_cache[relation.team_id] ||= {}
				relation_cache[relation.team_id][relation.character_id] = relation
			end

			puts "[relation loads] taken #{Time.now.to_f - start_time}" if debug
			
			team_list.each do |hash_id, data|
				data[:characters].each do |bnet_id, char_data|
					character_id = character_list[bnet_id][:character_id]
					begin
						relation = relation_cache[char_data[:team_id]] && relation_cache[char_data[:team_id]][character_id]
						if relation.nil?
							TeamCharacter.create(
								:team_id => char_data[:team_id],
								:character_id => character_id,
								:fav_race => RACES[char_data[:race]])
						elsif relation.fav_race != RACES[char_data[:race]]
							relation.fav_race = RACES[char_data[:race]]
							relation.save
						end
					rescue ActiveRecord::StatementInvalid => e
					 	Armory::Worker.say "#{e.class}: #{e.message}"
						if e.message.match(/duplicate key value violates/)
							relation_cache[char_data[:team_id]] ||= {}
							relation_cache[char_data[:team_id]][character_id] = TeamCharacter.first(:conditions => {:team_id => char_data[:team_id], :character_id => character_id})
							retry
						end
					end
				end
			end
						
			puts "[relation checks] taken #{Time.now.to_f - start_time}" if debug

			# Handle clean up, check for anyone who isn't in this division according to our list, but is according to DB
			# those people will need to be rescanned to figure out what's up

			# No longer needed
			# TEMPORARY HACK
			# Pages seem to be returning 60 or 80 even if there are 100 players in a league
			# http://eu.battle.net/sc2/en/profile/356901/1/BobRoss/ladder/3548#current-rank
			# If we see <= 80 teams and we have 7 or more people who are getting bumped up, we will skip them for now 
			# To account for having sa, 80 teams to rescan, but we detect the <= 80 mark, will check it if we have more teams than possible needing a bump
			#to_promote = Team.count(:conditions => ["region = ? AND division_id = ? AND hash_id NOT IN (?) AND is_random = ? AND bracket = ?", division.region, division.id, team_list.keys, division.is_random, division.bracket]) || 0
			#if division.total_teams <= 80 && to_promote >= 7 && to_promote < division.total_teams
			#	Armory::Worker.say "Division change for bnet #{division.bnet_id}, but we have #{division.total_teams} teams and #{to_promote} teams to bump up, so skipping."
			#else
			
			if allow_demote
				Team.all(:conditions => ["region = ? AND division_id = ? AND id NOT IN (?) AND is_random = ? AND bracket = ?", division.region, division.id, team_ids, division.is_random, division.bracket], :include => :first_character).each do |team|
					next if team.first_character.nil?
					#Armory::Worker.say "Division change for team #{team.id}, was in #{team.division_id}"
					Armory::Queue.character(:region => team.first_character.region, :is_auto => true, :bnet_id => team.first_character.bnet_id, :name => team.first_character.name, :bracket => true, :tag => 1, :priority => 12)
					character_cache.delete(team.first_character.bnet_id)
				end

				puts "[change checks] taken #{Time.now.to_f - start_time}" if debug
			else
				puts "[change checks] skipped" if debug
			end
			
			# Again, we don't want to be queuing any teams and such inside, we just want to be done with it all
			#if !args[:block_queues].nil? && args[:cascade].nil?
			#	return "done"
			#end

			#character_cache.each do |bnet_id, data|
			#	character_list.delete(bnet_id) if !data.character_code.nil? && total_jobs >= 7500
			#end
			
			#if total_jobs <= 10000
			#	Armory::Queue.mass_characters(division.region, character_list)
			# We hit zee limit, lock it for 30 minutes
			#elsif total_jobs > 10001
			#	Rails.cache.write("queue/size", "10001", :raw => true, :expires_in => 30.minutes)
			#end

			puts "[misc changes checks] taken #{Time.now.to_f - start_time}" if debug
			
			return "done"
		end

=begin
<div class="data-label badge-bronze">

	<h3>
		1v1 Bronze <span>/</span>
		Division Hive Alpha <span>/</span>
		Rank 62
	</h3>
</div>

<div class="data-label badge-silver">
					<h3>
						2v2 무작위 실버 <span>/</span>
						거대괴수 세타 조 <span>/</span>

						27 순위
					</h3>
				</div>

<tr>
							<td class="align-center" style="width: 15px" onmouseover="Tooltip.show(this, '조 참가: 7/28/2010');">

									<img src="/sc2/static/images/icons/ladder/exclamation.gif" alt="" />
							</td>
							<td class="align-center" style="width: 40px">1번째</td>

								<td>

	<a href="/sc2/ko/profile/285363/1/아리스/"
	   class="race-protoss"
	   onmouseover="Tooltip.show(this, '#player-info-285363');">
										아리스
	</a>

									<div id="player-info-285363" style="display: none">
										<div class="tooltip-title">아리스</div>
										<strong>최고 순위:</strong> 1<br />
										<strong>이전 순위:</strong> 0<br />
										<strong>좋아하는 종족:</strong> 프로토스
									</div>

								</td>
							<td class="align-center">464</td>
							<td class="align-center">34</td>
							<td class="align-center">25</td>
						</tr>
						-------------- 2VS2 ENGLISH BELOW ---------------
						<tr>
													<td class="align-center" style="width: 15px" onmouseover="Tooltip.show(this, 'Joined Division: 7/28/2010');">
															<img src="/sc2/static/images/icons/ladder/exclamation.gif" alt="" />
													</td>
													<td class="align-center" style="width: 40px">1st</td>

														<td>

							<a href="/sc2/en/profile/307617/1/Pooslice/"
							   class="race-random"
							   onmouseover="Tooltip.show(this, '#player-info-307617');">
																Pooslice
							</a>

															<div id="player-info-307617" style="display: none">
																<div class="tooltip-title">Pooslice</div>
																<strong>Highest Rank:</strong> 1<br />

																<strong>Previous Rank:</strong> 0<br />
																<strong>Favorite Race:</strong> Random
															</div>
														</td>

														<td>

							<a href="/sc2/en/profile/310799/1/Kuryakin/"
							   class="race-random"
							   onmouseover="Tooltip.show(this, '#player-info-310799');">

																Kuryakin
							</a>

															<div id="player-info-310799" style="display: none">
																<div class="tooltip-title">Kuryakin</div>
																<strong>Highest Rank:</strong> 1<br />
																<strong>Previous Rank:</strong> 0<br />

																<strong>Favorite Race:</strong> Random
															</div>
														</td>
													<td class="align-center">728</td>
													<td class="align-center">27</td>
													<td class="align-center">13</td>
												</tr>


=end
	end
end
