class Achievement < ActiveRecord::Base
	ICON_SIZES = {:small => 45, :medium => 75}
	
	def world_competition
		return self.world_earned_by || (Rails.cache.fetch("pop/achieve/world/#{self.achievement_id}", :raw => true, :expires_in => 6.hours) do
			CharacterAchievement.count(:conditions => ["achievement_id = ?", self.achievement_id])
		end).to_i
	end

	# x = column, y = row
	def image_size(type)
		return ICON_SIZES[type]
	end
	
	def sprite_location(type)
		y = -(self.icon_row * ICON_SIZES[type])
		x = -(self.icon_column * ICON_SIZES[type])
		return "#{x}px #{y}px"
	end
	
	def image_name(type)
		return "achievements-#{self.icon_id}-#{ICON_SIZES[type]}.jpg"
	end

	def self.row_from_y(y, size)
		return y.abs / size
	end
	
	def self.column_from_x(x, size)
		return x.abs / size
	end
		
	# Turn the row/column into a pseudo-id, shift id up one to stop 0s making it a <1000 ID
	def self.id_from_sprite(icon_id, x, y, size)
		column = (x.abs / size) + 1
		row = (y.abs / size) + 1
		return ((icon_id + 1) * 10000) + (row * 100) + column
	end
end
