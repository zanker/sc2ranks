class AddBonusPoolToDivisions < ActiveRecord::Migration
  def self.up
    add_column :divisions, :bonus_pool, :integer
  end

  def self.down
    remove_column :divisions, :bonus_pool
  end
end
