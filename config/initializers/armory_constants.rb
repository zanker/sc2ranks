EXPANSIONS = {
	0 => "Wings of Liberty",
	1 => "Heart of the Swarm"
}

SHORT_EXPANSIONS = {
	0 => "WoL",
	1 => "HoTS"
}

CURRENT_EXPANSION = 1

BNET_URLS = {
	"us" => "http://us.battle.net",
	"eu" => "http://eu.battle.net",
	"kr" => "http://kr.battle.net",
	"tw" => "http://tw.battle.net",
	"sea" => "http://sea.battle.net",
	"ru" => "http://eu.battle.net",
	"la" => "http://us.battle.net",
	"cn" => "http://www.battlenet.com.cn",
}

PATCH_BUILDS = {
	16195 => "1.0.1",
	16223 => "1.0.2",
	16291 => "1.0.3",
	16561 => "1.1.0",
	16605 => "1.1.1",
	16755 => "1.1.2",
	16939 => "1.1.3",
	17328 => "1.2.0",
	18092 => "1.3.0",
	19132 => "1.3.5",
	16776 => "1.4.1",
	20141 => "1.4.2"
}

PATCH_SELECT = [["All", "all"]]

list = PATCH_BUILDS.dup
list[22418] = "1.4.4"
list[21029] = "1.4.3"
list[22612] = "1.5.0"
list[22763] = "1.5.1"
list[22875] = "1.5.2"
list[23260] = "1.5.3"
list[24540] = "1.5.4"
list[24944] = "2.0.4"

list.keys.sort.reverse.each do |build|
	PATCH_SELECT.push([list[build], build])
end

# Patch data obviously
PATCHES = {103 => "[S1] 1.0.3", 110 => "[S1] 1.1.0", 112 => "[S1] 1.1.2", 120 => "[S1] 1.2.0", 130 => "[S2] 1.3.0", 135 => "[S3] 1.3.5", 141 => "[S4] 1.4.1", 142 => "[S5] 1.4.2"}
PATCH_ORDER = PATCHES.keys.sort
LATEST_PATCH = PATCH_ORDER.last

PATCHES_SELECT = []
PATCH_ORDER.reverse.each do |patch|
	if patch == LATEST_PATCH
		PATCHES_SELECT.push(["#{PATCHES[patch]} (Live)", patch])
	else
		PATCHES_SELECT.push([PATCHES[patch], patch])
	end
end

# Custom bracket ids
HISTORY_RESULT_NAMES = {
	-1 => "Unknown",
	1 => "Win",
	2 => "Loss",
	3 => "Observer", # Watcher
	4 => "Left", # Bailer
	5 => "Tie",
	6 => "Undecided",
	7 => "Disagree", # Disagree
}

HISTORY_RESULT_FEED_NAMES = {
	-1 => "Unknown",
	1 => "Won",
	2 => "Lost",
	3 => "Observed", # Watcher
	4 => "Left", # Bailer
	5 => "Tied",
	6 => "Undecided",
	7 => "Disagree", # Disagree
}

HISTORY_RESULTS = {
	-1 => "unknown",
	1 => "win",
	2 => "loss",
	3 => "watcher",
	4 => "bailer",
	5 => "tie",
	6 => "undecided",
	7 => "disagree",
}

USED_HISTORY_RESULTS = [1, 2, 3, 5]

HISTORY_RESULTS.keys.each do |key|
	HISTORY_RESULTS[HISTORY_RESULTS[key]] = key
end

HISTORY_BRACKET_ORDER = [1, 2, 3, 4, 200, 100, 300]

HISTORY_BRACKETS = {
	"unknown" => -1,
	"ffa" => 200,
	"custom" => 100,
	"co_op" => 300,
	-1 => "unknown",
	200 => "ffa",
	100 => "custom",
}

HISTORY_BRACKET_NAMES = {
	-1 => "Unknown",
	1 => "1v1",
	2 => "2v2",
	3 => "3v3",
	4 => "4v4",
	100 => "Custom",
	200 => "Free for All",
	300 => "Co-op",
}

HISTORY_BRACKET_LIST = [200, 100]

# Tracked achievements
ACHIEVEMENT_CATEGORIES = {
	4325378 => "Solo League",
	3211285 => "Story Mode",
	4325390 => "Race A.I.",
	4325385 => "Team League",
	3211272 => "League Combat",
	3211271 => "Melee Combat",
	3211270 => "Economy",
	4325394 => "Feats of Strength",
}

ACHIEVEMENT_DEFAULT = 3211285

LOG_TYPES = {
	:removed => 0,
	:added => 1,
	:reverted_remove => 2,
	:reverted_add => 3,
}

STAT_TYPES = {
	"leagues-by-regions" => 0,
	"races-by-leagues" => 1,
	"racewins-by-leagues" => 2,
	"racewins-by-regions" => 3,
	"races-by-regions" => 4,
	"racepoints-by-leagues" => 5,
	"racepoints-by-regions" => 6,
	"population-by-region" => 7,
}


RACES = {
	"unknown" => -1,
	"zerg" => 0,
	"protoss" => 1,
	"terran" => 2,
	"random" => 3,

	-1 => "unknown",
	0 => "zerg",
	1 => "protoss",
	2 => "terran",
	3 => "random",
}

RACE_LIST = [
	3, 1, 2, 0
]

RACE_NAMES = {
	0 => "Zerg",
	1 => "Protoss",
	2 => "Terran",
	3 => "Random",
}

LEAGUES = {
	"none" => -1,
	"bronze" => 0,
	"silver" => 1,
	"gold" => 2,
	"platinum" => 3,
	"diamond" => 4,
	"master" => 5,
 	"grandmaster" => 6,
	
	-1 => "none",
	0 => "bronze",
	1 => "silver",
	2 => "gold",
	3 => "platinum",
	4 => "diamond",
	5 => "master",
	6 => "grandmaster",
}

DEFAULT_LEAGUE = LEAGUES["grandmaster"]

LEAGUE_LIST = [6, 5, 4, 3, 2, 1, 0]

BRACKETS = [1, 2, 3, 4]

LEAGUE_NAMES = {
	0 => "Bronze",
	1 => "Silver",
	2 => "Gold",
	3 => "Platinum",
	4 => "Diamond",
	5 => "Master",
	6 => "Grandmaster",
}

LEAGUE_SELECT = [["Grandmaster", "grandmaster"], ["Master", "master"], ["Diamond", "diamond"], ["Platinum", "platinum"], ["Gold", "gold"], ["Silver", "silver"], ["Bronze", "bronze"]]
LEAGUE_SELECT_ALL = Array.new(LEAGUE_SELECT)
LEAGUE_SELECT_ALL.insert(0, ["All", "all"])

LOCALES = {
	"us" => "en",
	"eu" => "en",
	"tw" => "zh",
	"kr" => "ko",
	"sea" => "en",
	"la" => "en",
	"ru" => "en",
	"cn" => "zh"
}

# Forums can be on the same 'region' of battle.net, but are sectioned by the locale
FORUM_LOCALES = {
	"us" => "en",
	"eu" => "en",
	"tw" => "zh",
	"kr" => "ko",
	"sea" => "en",
	"la" => "pt",
	"ru" => "ru",
	"cn" => "zh"
}

LOCALE_IDS = {
	"us" => 1,
	"eu" => 1,
	"tw" => 2,
	"sea" => 1,
	"kr" => 1,
	"la" => 2,
	"ru" => 2,
	"cn" => 1,
}

RANK_REGIONS = {
  "us" => "am",
  "eu" => "eu",
  "la" => "am",
  "ru" => "eu",
  "kr" => "fea",
  "tw" => "fea",
  "cn" => "cn",
  "sea" => "sea"
}

RANK_REGIONS_GROUP = {}
RANK_REGIONS.each do |region, rank_region|
	RANK_REGIONS_GROUP[rank_region] ||= []
	RANK_REGIONS_GROUP[rank_region].push(region)
end

FORCE_REGION = {
	"la" => "am",
	"ru" => "eu",
}

SWITCH_REGIONS = {
	"2us" => "la",
	"2eu" => "ru",
}

REGION_NAMES = {
	"global" => "Global",
	"am" => "Americas",
	"eu" => "Europe",
	"fea" => "Korea / Taiwan",
	"sea" => "Southeast Asia",
	"cn" => "China",
}

SHORT_REGIONS = {
  "am" => "AM",
  "eu" => "EU",
  "fea" => "KR/TW",
  "sea" => "SEA",
  "cn" => "CN"
}

REGION_SELECT = [
  ["Americas", "am"],
  ["Europe", "eu"],
  ["Korea / Taiwan", "fea"],
  ["Southeast Asia", "sea"],
  ["China", "cn"]
]

ACHIEVEMENT_CAP = 5160

REGION_SELECT_ALL = REGION_SELECT.dup
REGION_SELECT_ALL.insert(0, ["Global", "all"])

REGION_SELECT_SHORT = [
  ["AM", "am"],
  ["EU", "eu"],
  ["KR/TW", "fea"],
  ["SEA", "sea"],
  ["CN", "cn"]
]

REGIONS = ["us", "la", "eu", "tw", "kr", "ru", "cn", "sea"]
RANK_REGIONS_LIST = RANK_REGIONS.values.uniq

REGIONS_GLOBAL = RANK_REGIONS_LIST.dup
REGIONS_GLOBAL.insert(0, "global")

REAL_REGIONS_GLOBAL = REGIONS.dup
REAL_REGIONS_GLOBAL.insert(0, "global")


