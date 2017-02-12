require "nokogiri"
require "uri"
require "cgi"

module Jobs
	class PullAchievements
		# http://eu.battle.net/sc2/en/profile/260628/1/rinku/achievements/
		def self.get_url(args)
			# Needs a trailing slash
			return "parse", ["profile", args[:bnet_id], LOCALE_IDS[args[:region]], URI.escape(args[:name]), "achievements", ""]
		end
		
		# Write the cached achievements to the DB
		def self.flush_achievements(region, achievement_list)
			return if region != "us"
			
			# Check if we've already looked at these achievements
			achievement_hash = Digest::SHA1.hexdigest("achievements/loaded/#{achievement_list.keys.sort.to_s}")
			return if Rails.cache.read(achievement_hash, :raw => true, :expires_in => 24.hours)
			
			# Pull anything we already have
			achievement_cache = {}
			Achievement.all(:conditions => ["achievement_id IN (?)", achievement_list.keys]).each do |achievement|
				achievement_cache[achievement.achievement_id] = achievement
			end
			
			achievement_list.each do |achievement_id, data|
				achievement = achievement_cache[achievement_id] || Achievement.new(:achievement_id => achievement_id)
				if data[:finished_at] && ( ( achievement.finished_at.nil? || achievement.finished_at < data[:finished_at] ) || data[:force_finished] == true )
					achievement.finished_at = data[:finished_at]
				else
					achievement.finished_at ||= 0
				end
				
				achievement.name ||= data[:name]
				achievement.description ||= data[:description]
				achievement.bnet_id ||= data[:bnet_id]
				achievement.category_id ||= data[:category_id]
				achievement.is_meta = data[:is_meta] ? true : false
				achievement.is_parent = data[:is_parent] ? true : false
				achievement.icon_row ||= data[:icon_row]
				achievement.icon_column ||= data[:icon_column]
				achievement.icon_id ||= data[:icon_id]
				achievement.points = data[:points] || 0
				achievement.series_id = data[:series_id]
				achievement.save
			end
			
			# Tell the workers that we've already checked this in the last 24 hours, no need to do it again
			Rails.cache.write(achievement_hash, "1", :raw => true, :expires_in => 24.hours)
		end

		def self.parse(args, doc, raw_html)
			# Now create the character or update it
			character = Character.first(:conditions => {:bnet_id => args[:bnet_id], :region => args[:region]}) 
			return unless character
			
			# Set how many achievement points we had when we did this update
			achievement_doc = doc.xpath("//div[@id='profile-header']/h3")
			if achievement_doc
				achievement_points = achievement_doc.text().to_i || 0
			end
			
			# If nothing changed, then exit rather than repull
      # return if character.updated_achievements == achievement_points
			character.updated_achievements = achievement_points
			
			achievement_data = {}
			achievement_ids = []
			
			recent_achievements = {}	
			
			# Do recently earned
			doc.xpath("//div[@id='recent-achievements']/a").each do |parent_doc|
				span_list = parent_doc.css("span")
				
				icon = span_list.first.attr("style").to_s
				icon_id = icon.match(/achievements\/([0-9]+)-([0-9]+)\.jpg/)
				sprite_loc = icon.match(/\) (-[0-9]+|[0-9]+)px (-[0-9]+|[0-9]+)px/s)
				
				next unless icon && icon_id && sprite_loc
				
				image_size = icon_id[2].to_i
				icon_x = sprite_loc[1].to_i
				icon_y = sprite_loc[2].to_i

				achievement_id = Achievement.id_from_sprite(icon_id[1].to_i, icon_x, icon_y, image_size)
				category_id = parent_doc.attr("href").to_s.match(/([0-9]+)/)[1].to_i
				recent_id = parent_doc.attr("onmouseover")
				recent_id = recent_id && recent_id.match(/([0-9]+)/)[1].to_i || nil
				next unless recent_id
			
				data = parent_doc.text.strip.split("\r\n")
				description = doc.css("div[@id='achv-recent-#{recent_id}']").inner_html.split("<\/div>")[1].strip
				
				achievement_data[achievement_id] = {:name => data[0].strip, :description => description, :category_id => category_id, :icon_row => Achievement.row_from_y(icon_y, image_size), :icon_column => Achievement.column_from_x(icon_x, image_size), :icon_id => icon_id[1].to_i}
				
				recent_achievements[achievement_id] =  {:achievement_id => achievement_id, :earned_on => character.achievements.translate_date(data[1].strip, args[:region]), :is_recent => true}
			end
			
			# Update achievements
			remove_recent = []
			add_recent = []
			character.achievements.all(:conditions => ["achievement_id IN (?) OR is_recent = ?", recent_achievements.keys, true]).each do |recent|
				# We already have the achievement saved, but the recent flag is not set
				if recent_achievements[recent.achievement_id].nil?
					remove_recent.push(recent.id)
				elsif recent.is_recent.nil?
					add_recent.push(recent.id)
				end

				recent_achievements.delete(recent.achievement_id)
			end
			
			if add_recent.length > 0
				character.achievements.update_all(["is_recent = ?", true], ["id IN (?)", add_recent])
			end

			if remove_recent.length > 0
				character.achievements.update_all(["is_recent = ?", nil], ["id IN (?)", remove_recent])
			end
			
			# Create anything we don't already have
			recent_achievements.each do |achievement_id, data|
				character.achievements.create(data)
			end
									
			# Handle parent categories
			parent_achievements = []
			doc.xpath("//div[@id='progress-module']//div[@class='progress-tile']").each do |parent_doc|
				icon = parent_doc.css("span[@class='portrait-a']").inner_html
				icon_id = icon.match(/achievements\/([0-9]+)-([0-9]+)\.jpg/)
				sprite_loc = icon.match(/\) (-[0-9]+|[0-9]+)px (-[0-9]+|[0-9]+)px/s)
				achievement_link = parent_doc.css("a[@class='progress-link']")
				achievement_points = parent_doc.css("div[@class='profile-progress'] > span")
				achievement_percent = parent_doc.css("div[@class='profile-progress'] > div > div")
				  				
				next unless icon_id && sprite_loc && achievement_link && achievement_points

				image_size = icon_id[2].to_i
				icon_x = sprite_loc[1].to_i
				icon_y = sprite_loc[2].to_i
				achievement_id = Achievement.id_from_sprite(icon_id[1].to_i, icon_x, icon_y, image_size)
				achievement_name =  achievement_link.text.strip
				category_id = achievement_link.attr("href").to_s.match(/([0-9]+)/)[1].to_i
			
				points_progress = achievement_points.text.to_i
				points_finished = 0
				percent_progress = (achievement_percent.attr("style").to_s.gsub(/%/, "").gsub(/width: /, "").to_f) / 100
				
				if percent_progress > 0
					points_finished = (points_progress / percent_progress).round
				else
					points_finished = (Rails.cache.fetch("finished/category/points/#{achievement_id}", :raw => true, :expires_in => 24.hours) do
						parent = Achievement.first(:conditions => {:achievement_id => achievement_id})
						parent && parent.finished_at || 0
					end).to_i
				end
								
				achievement = character.achievements.first(:conditions => {:achievement_id => achievement_id}) || character.achievements.new(:achievement_id => achievement_id)
				achievement.progress = points_progress.to_f
				achievement.earned_on ||= Time.now.utc if points_progress >= points_finished
				achievement.save
				
				parent_achievements.push(achievement_id)
				achievement_data[achievement_id] = {:name => achievement_name, :category_id => category_id, :icon_row => Achievement.row_from_y(icon_y, image_size), :icon_column => Achievement.column_from_x(icon_x, image_size), :icon_id => icon_id[1].to_i, :finished_at => points_finished, :is_parent => true, :force_finished => percent_progress >= 1}
			end
			
			# Clean up any parent achievements from someone having parent A and moving to parent B in the next level
			character.achievements.all(:conditions => ["character_achievements.achievement_id NOT IN (?) AND achievements.is_parent = ?", parent_achievements, true], :joins => "LEFT JOIN achievements ON achievements.achievement_id = character_achievements.achievement_id").each do |achievement|
				achievement.delete
			end
			
			# Flush
			achievement_ids = achievement_ids | achievement_data.keys
			self.flush_achievements(args[:region], achievement_data)
			
			# Now do the categories we scan
			url_args = ["profile", args[:bnet_id], LOCALE_IDS[args[:region]], URI.escape(args[:name]), "achievements", "category", 0]
			ACHIEVEMENT_CATEGORIES.keys.each do |category_id|
				url_args[url_args.length - 1] = category_id
				begin
					cat_response, url = Armory::Node.pull_custom_data(args[:region], url_args)
					cat_doc = Nokogiri::HTML(cat_response)
				
					next if cat_response.blank? && cat_doc.blank?
				rescue EOFError, OpenURI::HTTPError => e
					puts "#{e.class}: #{e.message} (#{url})"
					next
				end
				
				# Do this in sections instead of one mass transaction
				has_achievements = {}
				cat_doc.xpath("//div[@id='achievements-wrapper']/div").each do |achievement_doc|
				  bnet_id = achievement_doc.attr("id")
				  next if bnet_id.nil?
				  
					bnet_id = bnet_id.match(/([0-9]+)/)[1].to_i
					icon = achievement_doc.css("div > .icon").inner_html
					
					icon_id = icon.match(/achievements\/([0-9]+)-([0-9]+)\.jpg/)
					sprite_loc = icon.match(/\) (-[0-9]+|[0-9]+)px (-[0-9]+|[0-9]+)px/s)
					
					meta_data = achievement_doc.css(".inner > .meta.png-fix").text.strip.split("\r\n")
					points = meta_data[0].strip.to_i
					earned_on = meta_data.length > 1 && character.achievements.translate_date(meta_data.last.strip, args[:region]) || nil

					next unless bnet_id && points && icon && icon_id && sprite_loc
									
					image_size = icon_id[2].to_i
					icon_x = sprite_loc[1].to_i
					icon_y = sprite_loc[2].to_i

					achievement_id = Achievement.id_from_sprite(icon_id[1].to_i, icon_x, icon_y, image_size)
					data = achievement_doc.css(".desc").text.strip.split("\r\n")
					next if data[0].nil? or data[1].nil?
					
					# Figure out progress, type of achievemen ttoo
					progress, points_finished = 0, 0
					is_meta = false
					
					# Check for progression criteria, eg win 50 games, progress 25 / 50
					progress_data = achievement_doc.css("div.achievements-progress > span").text.split("/")
					if progress_data.length > 0
						progress = progress_data[0] && progress_data[0].strip.to_i || 0
						points_finished = progress_data[1] && progress_data[1].strip.to_i || 0
					else
						# Check for meta criteria
						progress = achievement_doc.css("div.series-criteria > ul > li.earned").length
						points_finished = achievement_doc.css("div.series-criteria > ul > li").length
						
						# Check for meta criteria (another type), but is completed
						if points_finished > 0 && progress == 0 && !earned_on.blank?
							progress = achievement_doc.css("div.series-criteria > ul > li.list-badge").length
						end
						
						is_meta = true if progress > 0 || points_finished > 0
					end
										
					# Save record of player getting it
					has_achievements[achievement_id] = {:progress => progress, :earned_on => earned_on}

					# Save achievement data
					achievement_data[achievement_id] = {:name => CGI.unescape(data[0]).strip, :description => CGI.unescape(data[1]).strip, :bnet_id => bnet_id, :category_id => category_id, :icon_row => Achievement.row_from_y(icon_y, image_size), :icon_column => Achievement.column_from_x(icon_x, image_size), :icon_id => icon_id[1].to_i, :finished_at => points_finished, :is_meta => is_meta, :points => points}
					
					# Figure out if it's a series
					series_id = nil
					series_list = achievement_doc.css("div.series > div.series-content > div.series-tiles > div")
					if series_list.length > 0
						# Set the first achievement to be the series master
						series_id = achievement_id
						achievement_data[achievement_id][:series_id] = series_id
						
						# Grab them all
						series_list.each do |tile_doc|
							# We can't get when an achievement is earned, so we have to cheat and say it's when we saw it
							tile_earned = tile_doc.attr("class").match(/tile\-locked/) ? false : true
							
							bnet_id = tile_doc.attr("id").match(/([0-9]+)/)[1].to_i
							tile_points = tile_doc.css(".series-badge").text.to_i
							
							tile_icon = tile_doc.css(".portrait-c").inner_html
							icon_id = tile_icon.match(/achievements\/([0-9]+)-([0-9]+)\.jpg/)
							sprite_loc = tile_icon.match(/\) (-[0-9]+|[0-9]+)px (-[0-9]+|[0-9]+)px/s)
							
							next unless bnet_id && tile_points && tile_icon && icon_id && sprite_loc

							image_size = icon_id[2].to_i
							icon_x = sprite_loc[1].to_i
							icon_y = sprite_loc[2].to_i

							achievement_id = Achievement.id_from_sprite(icon_id[1].to_i, icon_x, icon_y, image_size)
							
							data = tile_doc.css("#series-tooltip-#{bnet_id}").text.strip.split("\r\n")
														
							# Since we can't get when it was earned, will cheat and say it was earned when we saw it
							unless has_achievements[achievement_id]
								has_achievements[achievement_id] = {:earned_on => tile_earned == true && Time.parse("Today 00:00 UTC") || nil}
							end
							
							# Set series data
							achievement_data[achievement_id] = {:name => CGI.unescape(data[0].strip), :description => CGI.unescape(data.last.strip), :bnet_id => bnet_id, :category_id => category_id, :icon_row => Achievement.row_from_y(icon_y, image_size), :icon_column => Achievement.column_from_x(icon_x, image_size), :icon_id => icon_id[1].to_i, :is_meta => false, :points => tile_points, :series_id => series_id}
						end
					end
				end
				
				# Update achievements
				achievement_cache = {}
				character.achievements.all(:conditions => ["achievement_id IN (?)", has_achievements.keys]).each do |achievement|
					# We don't want to update achievements that we already earned
					if achievement.earned_on.blank?
						achievement_cache[achievement.achievement_id] = achievement
					else
						has_achievements.delete(achievement.achievement_id)
					end
				end
				
				if has_achievements.length > 0
					ActiveRecord::Base.transaction do
						has_achievements.each do |achievement_id, data|
							next if data[:earned_on].nil?
							
							achievement = achievement_cache[achievement_id] || character.achievements.new(:achievement_id => achievement_id)
							achievement.progress = data[:progress]
							achievement.earned_on = data[:earned_on]
							achievement.save
						end
					end
				end
				
				# Flush out anything from this group	
				achievement_ids = achievement_ids | achievement_data.keys
				self.flush_achievements(args[:region], achievement_data)
			end

			# Flush out anything left, shouldn't be
			if achievement_data.length > 0
				achievement_ids = achievement_ids | achievement_data.keys
				self.flush_achievements(args[:region], achievement_data)
			end
			
			# Kill anything we don't have an id for
			if achievement_ids.length > 0
				CharacterAchievement.delete_all(["character_id IN (?) AND achievement_id NOT IN (?)", character.id, achievement_ids.uniq!])
			end

			# Parse caharacter info we had, save and we're good
			Jobs::Profile.save_character(character, doc, raw_html)
		end
	end
end
