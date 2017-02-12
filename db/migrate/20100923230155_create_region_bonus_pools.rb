class CreateRegionBonusPools < ActiveRecord::Migration
  def self.up
    create_table :region_bonus_pools do |t|
      t.integer :max_pool
      t.string :region
    end

	add_index :region_bonus_pools, :region
  end

  def self.down
    drop_table :region_bonus_pools
  end
end
