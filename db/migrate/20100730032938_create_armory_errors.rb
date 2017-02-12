class CreateArmoryErrors < ActiveRecord::Migration
	def self.up
		create_table :armory_errors do |t|
			t.string :region
			t.string :error_type
			t.string :class_name
			t.integer :bnet_id
			t.integer :bracket
			t.datetime :created_at
		end

		add_index :armory_errors, :region
		add_index :armory_errors, :class_name
		add_index :armory_errors, :bnet_id
	end

	def self.down
		drop_table :armory_errors
	end
end
