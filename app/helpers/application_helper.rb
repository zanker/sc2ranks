class Integer
	def ordinal
		to_s + ([[nil, 'st','nd','rd'],[]][self / 10 == 1 && 1 || 0][self % 10] || 'th')
	end
end

module ApplicationHelper
	def make_badge(league, badge_id=1, size="small")
		if size.match(/[0-9]+x[0-9]+/)
			image_tag("leagues/tiny/#{league}-#{badge_id}.png", :size => size, :class => "imgbadge")
		else
			content_tag(:span, "", :class => "badge badge-#{league} badge-#{size}-#{badge_id}")
		end
	end	

	def badge_by_rank(rank, league, size="small")
		return make_badge("none", 1, size) if league.nil?
		rank = rank.to_i
		
		badge_id = 1
		if rank <= 100
			badge_id = 4
		elsif rank <= 1000
			badge_id = 3
		elsif rank <= 10000
			badge_id = 2
		end
		
		make_badge(LEAGUES[league], badge_id, size)
	end
	
  	def team_badge(team, size="small")
		return make_badge("none", 1, size) if team.nil?
		rank = rank.to_i
			
		badge_id = 1
		if team.league <= LEAGUES["master"]
			if team.division_rank <= 8
				badge_id = 4
			elsif team.division_rank <= 25
				badge_id = 3
			elsif team.division_rank <= 50
				badge_id = 2
			end
		else
			if team.division_rank <= 16
				badge_id = 4
			elsif team.division_rank <= 50
				badge_id = 3
			elsif team.division_rank <= 100
				badge_id = 2
			end
		end
		
		make_badge(LEAGUES[team.league], badge_id, size)
	end
		
  def can_link_to(*args)
    args[3] ||= {}
    args[3][:rel] = :canonical
    
    return link_to(*args)
  end
  
  def can_link_to_unless(text, link)
    return link_to_unless_current(text, link, {:rel => :canonical})
  end
  
	def build_bookmarks(ids)
		return nil if ids.blank?
		return Rails.cache.fetch("bookmark/#{ids}", :raw => true, :expires_in => 24.hours) do
			characters = []
			ids.split(",").each do |id|
				id = id.to_i
				next unless id > 0
				characters.push(id)
			end
		
			if characters.length > 0
				names = ""
				Character.all(:conditions => ["id IN(?)", characters]).each do |character|
					names << content_tag(:div, "", :class => "rowsep") unless names.blank?
					names << content_tag(:li, 
						can_link_to("#{character.region.upcase} - #{character.name}#{character.character_code.blank? ? "" : "##{character.character_code}"}", character_path(character.region, character.bnet_id, character.name)),
						:class => cycle("darkbg", "lightbg"))
				end
				
				html = content_tag(:li,
						content_tag(:div, "Saved profiles", :class => "text") <<
						content_tag(:div, "", :class => "arrow down") <<
						content_tag(:ul, names, :class => "invisible"),
						:class => "dropdown")
			else
				html = ""
			end
			
			html
		end
	end
	
	def parameterize(text)
		return text.match(/[a-zA-Z]+/) ? text.parameterize : ""
	end
	
	def pagination_url(offset)
		return url_for(params.merge(:offset => offset))
	end
	
	def build_pagination(per_page, total_rows, css)
		return nil if total_rows < per_page
				
		offset = params[:offset].to_i
		previous_offset = offset > per_page ? offset - per_page : 0
		next_offset = (offset + per_page) >= total_rows ? total_rows - per_page : offset + per_page		
		
		current_page = (offset.to_f / per_page).ceil + 1
		total_pages = (total_rows.to_f / per_page).ceil
				
		html = ""
		if offset > 0
			html << content_tag(:div,
				can_link_to("<<", pagination_url(0), :class => "first", :title => "First page") <<
				can_link_to("\< Previous", pagination_url(previous_offset), :title => "Back to page #{current_page - 1}"),
				:class => "previous")
		else
			html << content_tag(:div, "&nbsp;", :class => "previous")
		end
		
		html << content_tag(:div,
			"Page #{text_field(:page, :offset, :value => current_page)} of #{number_with_delimiter(total_pages)}",
			:class => "page")
		
		if (offset + per_page) < total_rows
			html << content_tag(:div,
				can_link_to("Next \>", pagination_url(next_offset), :title => "Go to page #{current_page + 1}") <<
				can_link_to(">>", pagination_url(total_rows - per_page), :class => "last", :title => "Last page"),
				:class => "next") 
		else
			html << content_tag(:div, "&nbsp;", :class => "next")
		end
		
		return content_tag(:form,
			content_tag(:div, html, :class => css),
			:onsubmit => "redirect_to_page(this, '#{pagination_url("page")}', #{per_page}); return false;")
	end
	
	def map_type(map)
		is_blizzard = !map.is_blizzard.blank?
		return content_tag(:span, is_blizzard ? "Blizzard" : "Custom", :class => "map-#{is_blizzard ? "blizzard" : "custom"}")
	end
	
	def wrap_api_arg(text)
		return content_tag(:span, "[#{text}]", :class => "apiarg")
	end
	
	def is_mobile_ua?
		return nil if request.user_agent.nil?
		return request.user_agent.match(/Mobile|BlackBerry|Android|Windows CE|CLDC|Opera Mini|Palm|Pre\/1\.0/i) && !request.user_agent.match(/iPad/i) ? true : nil
	end
	
	def battlenet_url(character)
		return "#{BNET_URLS[character.region]}/sc2/#{LOCALES[character.region]}/profile/#{character.bnet_id}/#{LOCALE_IDS[character.region]}/#{character.name}/"
	end
	
	def is_active?(type)
		if flash[:tab_type]
			return flash[:tab_type] == type
		elsif type == "rankings" && params[:controller] != "character_search" && params[:controller] != "stats" && params[:controller] != "divisions" && params[:controller] != "profile_search" && params[:controller] != "replay_search"
			return true
		end
		
		return true if params[:controller] == type
	end

	def distance_in_words(seconds)
		if seconds < 1.minute
			return pluralize(seconds.round, "second", "seconds")
		elsif seconds < 60.minutes
			return pluralize((seconds / 1.minute).round, "minute", "minutes")
		elsif seconds < 1.day
			return pluralize((seconds / 1.hour).round, "hour", "hours")
		elsif seconds < 1.month
			return pluralize((seconds / 1.day).round, "day", "days")
		else
			return pluralize((seconds / 1.month).round, "month", "months")
		end
	end
	
	def day_words_or_time(time)
		seconds = Time.now.utc.to_i - time.to_i
		if seconds < 1.day
			return "Today"
		elsif seconds < 2.days
			return "Yesterday"
		else
			return time.strftime("%m/%d/%Y")
		end
	end
	
	def day_distance_in_words(seconds)
		if seconds < 1.day
			return "Today"
		elsif seconds < 2.days
			return "Yesterday"
		elsif seconds < 1.week
			return pluralize(seconds.to_i / 1.day, "day", "days")
		else
			return pluralize(seconds.to_i / 1.month, "month", "months")
		end
	end
end
