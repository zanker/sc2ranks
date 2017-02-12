ActionController::Routing::Routes.draw do |map|
	map.replay_search_format "/replays", :controller => "replay_search", :action => "reformat", :conditions => { :method => :post }
	map.replay_search "/replays/:region/:league/:bracket/:race/:patch/:offset", :controller => "replay_search", :action => "index", :defaults => { :region => "all", :league => "grandmaster", :bracket => 1, :race => "any", :offset => 0, :patch => "all" }
	
	map.masters "/masters/:region/:offset", :controller => "rankings", :action => "masters", :defaults => { :offset => 0 }, :requirements => { :region => /[a-zA-Z]+/ }
	map.masters_old "/masters/:offset", :controller => "rankings", :action => "masters", :defaults => { :offset => 0 }, :requirements => { :offset => /page|[0-9]+/ }
		
	map.faq "/faq", :controller => "faq", :action => "index"
	map.api "/api", :controller => "api", :action => "index"
	map.workers "/status", :controller => "workers", :action => "index"
	#map.stat_data "/dbdata", :controller => "stat_data", :action => "index"
	map.advertising "/ads", :controller => "ads", :action => "index"
	
	map.map_list "/map/:region/:offset", :controller => "maps", :action => "rankings", :defaults => { :offset => 0}, :requirements => { :region => /[a-zA-Z]+/ }
	map.map_info "/map/:id/:name", :controller => "maps", :action => "index", :defaults => { :name => "" }, :requirements => { :id => /[0-9]+/ }
	
	map.stats_achievements "/stats/achievements/:region/:category_id", :controller => "stats", :action => "achievements", :defaults => { :category_id => 0 }
	map.stats_parse "/stats/parse", :controller => "stats", :action => "format_url"
	map.stats_name "/stats/name/:region/:league/:bracket/:expansion", :controller => "stats", :action => "name"
	map.stats_region "/stats/region/:league/:bracket/:group/:activity/:patch/:expansion", :controller => "stats", :action => "region", :defaults => { :group => 0, :patch => 0, :expansion => CURRENT_EXPANSION, :activity => 0 }
	map.stats_league "/stats/league/:region/:bracket/:group/:activity/:patch/:expansion", :controller => "stats", :action => "league", :defaults => { :group => 0, :patch => 0, :expansion => CURRENT_EXPANSION, :activity => 0 }
	map.stats_race "/stats/race/:region/:bracket/:activity/:patch/:expansion", :controller => "stats", :action => "race", :defaults => { :patch => 0, :activity => 0, :expansion => CURRENT_EXPANSION}
	map.stats_index "/stats/:region/:bracket/:group/:expansion", :controller => "stats", :action => "summary_index", :defaults => {:expansion => CURRENT_EXPANSION}
	map.stats_changes "/stats/changes", :controller => "stats", :action => "overall_changes"
	map.stats_changes_top "/stats/changes/top", :controller => "stats", :action => "overall_top_changes"
	map.misc_stats "/stats/misc", :controller => "stats", :action => "misc"
	map.stats "/stats", :controller => "stats", :action => "summary_index"
	
	map.character_code "/charcode/:region/:code/:name", :controller => "character", :action => "character_code"
	map.character_refresh "/char/refresh/:region/:bnet_id/:name", :controller => "character", :action => "refresh"
	map.character_reformat "/char", :controller => "character", :action => "reformat", :conditions => { :method => :post }
	map.character_old "/char/:region/:bnet_id/:name", :controller => "character", :action => "reformat_old_url"
	
	# For excal
	map.division_names "/divisions/name/:region/:name/:sort/:offset", :action => "divisions_by_name", :controller => "divisions", :defaults => {:sort => "ratio", :offset => 0}
	
	# Profile search controller
	map.profile_reformat "/psearch", :controller => "profile_search", :action => "search", :conditions => { :method => :post }
	map.profile_search "/psearch/:region/:name/:type/:sub_type/:value", :controller => "profile_search", :action => "index"
	#map.profile_search "/psearch/:region/:name/:type/:comparison/:value", :controller => "profile_search", :action => "index"
	
	# Mobile API for official use!
	map.mobile_profile_manage "/mobile/profile/manage", :controller => "mobile", :action => "profile_modified", :conditions => { :method => :post }
	map.mobile_profile_find "/mobile/profile/find", :controller => "mobile", :action => "profile_find", :conditions => { :method => :post }
	map.mobile_profiles "/mobile/profile", :controller => "mobile", :action => "profiles", :conditions => { :method => :post }
	map.mobile_rankings "/mobile/rankings", :controller => "mobile", :action => "rankings", :conditions => { :method => :post }
	map.mobile_team "/mobile/team", :controller => "mobile", :action => "team", :conditions => { :method => :post }
	map.mobile_character "/mobile/character", :controller => "mobile", :action => "character", :conditions => { :method => :post }
	map.mobile_search "/mobile/search", :controller => "mobile", :action => "search", :conditions => { :method => :post }
	
	# RSS/Atom Feeds
	map.match_history_feed "/feed/matches/:character_id.:format", :controller => "feeds", :action => "match_history"
	map.team_history_feed "/feed/team/:team_id.:format", :controller => "feeds", :action => "team_history"
	
	map.replay_feed "/feed/replays/:character_id.:format", :controller => "feeds", :action => "replays"
	
	# Generics
	map.api_profile_search "/api/psearch/:region/:name/:type/:sub_type/:value.:format", :controller => "api", :action => "profile_search"
	map.api_bonus_pool "/api/bonus/pool.:format", :controller => "api", :action => "bonus_pools"

	# SC2Mapster API
	map.api_single_map_pop "/api/map/:map_id.:format", :controller => "api", :action => "single_map_popularity", :requirements => { :map_id => /[0-9]+/ }
	map.api_map_population "/api/map/:region.:format", :controller => "api", :action => "map_popularity", :requirements => { :region => /[a-zA-Z]+/ }

	# IGN API
	map.api_rankings "/api/ign/rankings/:region.:format", :controller => "api", :action => "rankings"
		
	# Division management
	map.custom_div_list_api "/api/clist/:id/:region/:league/:bracket/:is_random.:format", :controller => "api", :action => "custom_div_list"
	map.api_chars_add "/api/custom/:id/:password/:type/:characters", :controller => "api", :action => "manage_custom"

	# Search
	map.character_search_type "/api/search/:searchtype/:region/:name.:format", :controller => "api", :action => "character_search"
	map.character_search_offset_type "/api/search/:searchtype/:region/:name/:offset.:format", :controller => "api", :action => "character_search", :defaults => { :offset => 0 }
	map.character_search "/api/search/:region/:name/:offset.:format", :controller => "api", :action => "character_search", :defaults => { :offset => 0 }
	
	# Single APIs
	map.api_character_teams "/api/base/teams/:region/:name.:format", :controller => "api", :action => "character"
	map.api_character_base "/api/base/char/:region/:name.:format", :controller => "api", :action => "base_character"

	map.api_character_team "/api/char/teams/:region/:name/:bracket/:is_random.:format", :controller => "api", :action => "team_character"
	
	map.api_name_map "/api/name/map", :controller => "api", :action => "name_map"
	
	# Mass APIs
	map.mass_api_character_teams "/api/mass/base/teams", :controller => "api", :action => "mass_character", :conditions => { :method => :post }
	map.mass_api_character_base "/api/mass/base/char", :controller => "api", :action => "mass_base_character", :conditions => { :method => :post }
	#map.mass_api_character_team "/api/mass/char/teams", :controller => "api", :action => "mass_team_characters", :conditions => { :method => :post }

	map.search_special "/search/:type/:region/:name/:offset", :controller => "character_search", :action => "index", :defaults => { :offset => 0 }, :requirements => { :type => /contains|starts|ends|exact/ }
	map.search_data_offset "/search/:region/:name/:offset", :controller => "character_search", :action => "index", :defaults => { :offset => 0}, :requirements => { :offset => /[0-9]+|page/ }

	map.search_friend "/search/code", :controller => "character_search", :action => "character_code", :conditions => { :method => :post }
	map.search "/search", :controller => "character_search", :action => "search", :conditions => { :method => :post }

	map.achievement_ranks "/ach/ranks/:achievement_id/:name/:offset", :controller => "achievements", :action => "achievement", :requirements => { :offset => /[0-9]+|page/ }, :defaults => { :offset => 0, :name => "" }
	map.achievement_list "/ach/:region/:offset", :controller => "achievements", :action => "index", :defaults => {:offset => 0}
	map.achievement_format "/ach", :controller => "achievements", :action => "url_format", :conditions => {:method => :post}
	
	map.rank_divisions_setup "/divs", :controller => "divisions", :action => "url_format", :conditions => { :method => :post }
	map.rank_filter_divisions "/div/:region/:league/:bracket/:sort/:offset/:expansion", :controller => "divisions", :action => "index", :defaults => {:expansion => CURRENT_EXPANSION}
	map.rank_division_bnet "/div/bnet/:division_id", :controller => "divisions", :action => "bnet_url"
	map.rank_division "/div/:division_id/:name", :controller => "divisions", :action => "player_rankings", :defaults => { :name => "" }
	
	map.team "/team/:team_id", :controller => "team", :action => "index"
	map.team_history "/team/history/:team_id", :controller => "team", :action => "team_history"
	
	map.rank_graph "/ranks/graph", :controller => "rankings", :action => "graph"
	
	map.rank_search "/ranks/search", :controller => "rankings", :action => "search", :conditions => { :method => :post }
	
	map.rank_setup "/ranks", :controller => "rankings", :action => "url_format", :conditions => { :method => :post }
	map.rank_filter "/ranks/:region/:league/:bracket/:race/:sort/:offset/:activity/:expansion", :controller => "rankings", :action => "index", :defaults => { :region => "all", :league => "grandmaster", :bracket => 1, :race => "all", :sort => "points", :offset => 0, :expansion => CURRENT_EXPANSION, :activity => 0 }
	map.gm_log "/gm/:offset", :controller => "rankings", :action => "gm_log", :defaults => { :offset => 0 }

	map.custom_division_list "/custom", :controller => "custom_rankings", :action => "list"
	map.custom_division_update "/custom_update", :controller => "custom_rankings", :action => "update", :conditions => { :method => :post }
	map.custom_division_update_chars "/custom_char_update", :controller => "custom_rankings", :action => "update_characters", :conditions => { :method => :post }
	map.custom_division_create "/custom_create", :controller => "custom_rankings", :action => "new"
	map.custom_division_format "/custom_format", :controller => "custom_rankings", :action => "url_format", :conditions => { :method => :post }

	map.custom_division_manage "/c/manage/:id", :controller => "custom_rankings", :action => "manage"
	map.custom_division_characters "/c/characters/:id", :controller => "custom_rankings", :action => "manage_characters"

	map.custom_div_unban "/c/unban/:id", :controller => "custom_rankings", :action => "unban"
	map.custom_div_ban "/c/ban/:id", :controller => "custom_rankings", :action => "ban"
	map.custom_div_logs "/c/logs/:id", :controller => "custom_rankings", :action => "logs"
	map.custom_div_revert "/c/revert/:id", :controller => "custom_rankings", :action => "revert_log"

        map.custom_division_region_offset "/c/:id/:region/:league/:bracket/:race/:sort/:offset/:expansion", :controller => "custom_rankings", :action => "index", :defaults => { :region => "all", :league => "all", :bracket => "1", :race => "all", :sort => "points", :offset => 0, :expansion => CURRENT_EXPANSION }, :requirements => { :region => /us|kr|la|sea|ru|eu|all/i }
        map.custom_division_offset "/c/:id/:league/:bracket/:race/:sort/:offset/:expansion", :controller => "custom_rankings", :action => "index", :defaults => {:expansion => CURRENT_EXPANSION}
	map.custom_division_name "/c/:id/:name/:offset", :controller => "custom_rankings", :action => "index", :defaults => { :offset => 0 }
	map.custom_division "/c/:id", :controller => "custom_rankings", :action => "index", :conditions => { :method => :get }

	map.character "/:region/:bnet_id/:name", :controller => "character", :action => "index"
	map.character_season "/:region/:bnet_id/:name/season/:season", :controller => "character", :action => "season"
	map.character_achievements "/:region/:bnet_id/:name/a/:category_id", :controller => "character", :action => "achievements", :defaults => { :category_id => 0 }
	map.character_map "/:region/:bnet_id/:name/maps/:offset", :controller => "character", :action => "maps", :defaults => { :offset => 0 }
	map.character_map_stats "/:region/:bnet_id/:name/map/:map_id/:map_name", :controller => "character", :action => "map_stats", :defaults => { :map_name => "" }
	map.character_replay "/:region/:bnet_id/:name/replays/:offset", :controller => "character", :action => "replays", :defaults => { :offset => 0 }
	map.character_vod "/:region/:bnet_id/:name/vods/:offset", :controller => "character", :action => "vods", :defaults => { :offset => 0 }
	map.character_rename "/rename/character", :controller => "character", :action => "rename_character", :conditions => { :method => :post }

	map.root :controller => "rankings"
end
