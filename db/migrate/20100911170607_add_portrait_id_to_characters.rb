class AddPortraitIdToCharacters < ActiveRecord::Migration
  def self.up
    add_column :characters, :portrait_id, :integer
  end

  def self.down
    remove_column :characters, :portrait_id
  end
end
