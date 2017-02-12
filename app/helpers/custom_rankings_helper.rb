module CustomRankingsHelper
	def grab_player_names(ids)
		characters = []
		Character.all(:conditions => "id IN (#{ids})").each do |character|
			characters.push(character.name) if character
		end
		
		return characters.join(", ")
	end
end
