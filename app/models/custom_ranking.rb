class CustomRanking < ActiveRecord::Base
	has_many :characters, :class_name => "CustomRankingCharacter", :dependent => :destroy
	has_many :logs, :class_name => "CustomRankingLogs", :dependent => :destroy
	has_many :bans, :class_name => "CustomRankingBans", :dependent => :destroy

	def is_authed?(cookies)
		return !cookies["div#{self.id}"].blank? && cookies["div#{self.id}"] == self.session_token ? true : nil
	end
end
