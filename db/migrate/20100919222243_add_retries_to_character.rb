class AddRetriesToCharacter < ActiveRecord::Migration
  def self.up
    add_column :characters, :retries, :integer
  end

  def self.down
    remove_column :characters, :retries
  end
end
