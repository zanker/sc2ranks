class CreateCustomRankings < ActiveRecord::Migration
  def self.up
    create_table :custom_rankings do |t|
      t.string :name
	  t.string :email
      t.string :message
      t.string :password
      t.string :password_salt
	  t.boolean :is_public
      t.boolean :allow_add
      t.boolean :allow_remove
	  t.datetime :updated_at
    end

	add_index :custom_rankings, :is_public
	add_index :custom_rankings, :name
  end

  def self.down
    drop_table :custom_rankings
  end
end
