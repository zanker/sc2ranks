class RenameBracketToTagInArmoryJobs < ActiveRecord::Migration
  def self.up
	rename_column :armory_jobs, :bracket, :tag
  end

  def self.down
	rename_column :armory_jobs, :tag, :bracket
  end
end
