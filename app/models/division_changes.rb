class DivisionChanges < ActiveRecord::Base
	has_one :team, :class_name => "Team", :primary_key => :team_id, :foreign_key => :id
	has_many :team_characters, :class_name => "TeamCharacter", :through => :team
end
