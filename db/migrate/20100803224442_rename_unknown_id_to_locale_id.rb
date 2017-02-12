class RenameUnknownIdToLocaleId < ActiveRecord::Migration
  def self.up
	rename_column :characters, :unknown_id, :locale_id
  end

  def self.down
	rename_column :characters, :locale_id, :unknown_id
  end
end
