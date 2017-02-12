class CustomRankingCharacter < ActiveRecord::Base
	belongs_to :custom_ranking
	belongs_to :character
	
	def self.parse_url(url)
		character = {}
		if url.match(/sc2ranks/)
			match = url.match(/sc2ranks.com\/([a-z]+)\/([0-9]+)\/(.+)/)
			if match
				character[:region] = match[1]
				character[:bnet_id] = match[2].to_i
				character[:name] = match[3]
			end
		elsif url.match(/battle\.net/)
			match = url.match(/sc2\/.+\/profile\/([0-9]+)\/([0-9]+)\/(.+?)\//i)
			region = url.match(/(us|kr|tw|sea|eu)\.battle\.net/i)
			
			if match && region
				character[:region] = region[1]
				character[:bnet_id] = match[1].to_i
				character[:name] = match[3]
				character[:region] = SWITCH_REGIONS[match[2] + character[:region]] || character[:region]
			end
		end
		
		return character
	end
end
