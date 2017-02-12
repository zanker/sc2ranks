class AddLowerNameToCharacter < ActiveRecord::Migration
  def self.up
    add_column :characters, :lower_name, :string
  end

  def self.down
    remove_column :characters, :lower_name
  end
end
