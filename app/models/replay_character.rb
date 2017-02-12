class ReplayCharacter < ActiveRecord::Base
	belongs_to :character
	belongs_to :replay
end
