class AddIsVerifiedToCharacters < ActiveRecord::Migration
  def self.up
    add_column :characters, :is_verified, :boolean
  end

  def self.down
    remove_column :characters, :is_verified
  end
end
