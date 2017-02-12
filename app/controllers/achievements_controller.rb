class AchievementsController < ApplicationController
	def url_format
		return root_path if params[:filter].nil?
		
		redirect_to achievement_list_path(params[:filter][:region])
	end
	
	def achievement
		achievement_id = params[:achievement_id].to_i

		@offset = params[:offset].to_i > 0 ? params[:offset].to_i : 0
		@region = params[:region] != "all" ? params[:region] : nil
		@page_hash = Digest::SHA1.hexdigest("achievements/ranks/#{achievement_id}/#{@region}/#{@offset}")
		
		etag = Rails.cache.read("#{@page_hash}/etag", :raw => true, :expires_in => 1.hour) 
		return unless etag.nil? || stale?(:etag => etag)

	 	@achievement = Achievement.first(:conditions => {:achievement_id => achievement_id})
		if @achievement.nil?
			flash[:error] = "Achievement ##{achievement_id} does not exist."
			return redirect_to root_path
		end
		
		unless read_fragment(@page_hash, :raw => true, :expires_in => 1.hour)
			Rails.cache.write("#{@page_hash}/etag", "#{@page_hash}/#{Time.now.to_i}", :raw => true, :expires_in => 1.hour)
			
			@total_chars = @achievement.world_competition
			@rankings = []
						
			conditions = @region ? ["characters.rank_region = ? AND character_achievements.achievement_id = ?", @region, achievement_id] : ["character_achievements.achievement_id = ?", achievement_id]
			rank = @offset
			skipped_increments = 0
			previous_date = nil
			CharacterAchievement.all(:select => "characters.*, character_achievements.earned_on", :conditions => conditions, :joins => "LEFT JOIN characters ON characters.id=character_achievements.character_id", :limit => 100, :offset => @offset, :order => "earned_on ASC").each do |character|
				next if character.nil? || character.region.nil?
				
				if previous_date.nil? || previous_date != character.earned_on
					rank += 1 + skipped_increments
					skipped_increments = 0
				else
					skipped_increments += 1
				end
				previous_date = character.earned_on
				
				character[:rank] = rank
				@rankings.push(character)
			end
		end
	end
	
	def index
		@offset = params[:offset].to_i > 0 ? params[:offset].to_i : 0
		@region = params[:region] != "all" ? params[:region] : nil
		@page_hash = Digest::SHA1.hexdigest("achievements/#{@region}/#{@offset}")
					
		etag = Rails.cache.read("#{@page_hash}/etag", :raw => true, :expires_in => 1.hour) 
		return unless etag.nil? || stale?(:etag => etag)
		
		unless read_fragment(@page_hash, :raw => true, :expires_in => 1.hour)
			Rails.cache.write("#{@page_hash}/etag", "#{@page_hash}/#{Time.now.to_i}", :raw => true, :expires_in => 1.hour)
			
			conditions = @region ? ["rank_region = ? AND achievement_points > 0", @region] : ["achievement_points > 0"]
			
			@total_chars = (Rails.cache.fetch("total/achievement/chars/#{@region}", :raw => true, :expires_in => 30.minutes) do
				Character.count(:conditions => conditions)
			end).to_i
			
			@rankings = []
			rank = @offset
			skipped_increments = 0
			previous_points = nil
			Character.all(:conditions => conditions, :order => "achievement_points DESC", :limit => 100, :offset => @offset).each do |character|
				if previous_points.nil? || previous_points != character.achievement_points
					rank += 1 + skipped_increments
					skipped_increments = 0
				else
					skipped_increments += 1
				end
				previous_points = character.achievement_points
				
				character[:rank] = rank
				@rankings.push(character)
			end
		end
	end
end
