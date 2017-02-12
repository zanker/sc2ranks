class AddFavRaceToTeamCharacters < ActiveRecord::Migration
  def self.up
    add_column :team_characters, :fav_race, :integer
  end

  def self.down
    remove_column :team_characters, :fav_race
  end
end
