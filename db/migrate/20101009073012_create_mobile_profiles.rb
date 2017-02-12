class CreateMobileProfiles < ActiveRecord::Migration
  def self.up
    create_table :mobile_profiles do |t|
		t.integer :character_id
		t.string :device_id
		t.datetime :updated_at
    end

	add_index :mobile_profiles, :device_id
  end

  def self.down
    drop_table :mobile_profiles
  end
end
