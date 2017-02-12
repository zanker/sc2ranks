class CreateNameChanges < ActiveRecord::Migration
  def self.up
    create_table :name_changes do |t|
      t.string :old_name
      t.string :new_name
      t.integer :character_id
	  t.datetime :updated_at
    end

	add_index :name_changes, :character_id
  end

  def self.down
    drop_table :name_changes
  end
end
