class CustomRankingBans < ActiveRecord::Base
	has_one :division, :class_name => "CustomRanking", :foreign_key => "id", :primary_key => "custom_ranking_id"
end
