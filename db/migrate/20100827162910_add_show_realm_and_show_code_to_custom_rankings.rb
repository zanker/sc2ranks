class AddShowRealmAndShowCodeToCustomRankings < ActiveRecord::Migration
  def self.up
    add_column :custom_rankings, :show_regions, :boolean
    add_column :custom_rankings, :show_codes, :boolean
  end

  def self.down
    remove_column :custom_rankings, :show_codes
    remove_column :custom_rankings, :show_regions
  end
end
