module MapsHelper
	def build_map_popularity(map)
		games = []
		map.stats.all(:conditions => ["stat_date > ?", 1.month.ago.midnight]).each do |date|
			games.push([date.stat_date.to_s(:js), date.total_games.to_i])
		end

		return javascript_tag("var games_data = #{games.to_json};")
	end
end
