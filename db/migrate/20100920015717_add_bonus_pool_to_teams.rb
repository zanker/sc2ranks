class AddBonusPoolToTeams < ActiveRecord::Migration
  def self.up
    add_column :teams, :bonus_pool, :integer
  end

  def self.down
    remove_column :teams, :bonus_pool
  end
end
