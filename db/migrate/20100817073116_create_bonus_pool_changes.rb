class CreateBonusPoolChanges < ActiveRecord::Migration
  def self.up
    create_table :bonus_pool_changes do |t|
	  t.string :region
      t.integer :division_id
      t.integer :bonus_pool
      t.integer :old_pool
	  t.datetime :created_at
    end
  end

  def self.down
    drop_table :bonus_pool_changes
  end
end
