class AddUnknownIdToCharacters < ActiveRecord::Migration
  def self.up
    add_column :characters, :unknown_id, :integer, :default => 1
  end

  def self.down
    remove_column :characters, :unknown_id
  end
end
