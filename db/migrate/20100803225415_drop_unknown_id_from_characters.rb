class DropUnknownIdFromCharacters < ActiveRecord::Migration
  def self.up
	remove_column :characters, :locale_id
  end

  def self.down
  end
end
