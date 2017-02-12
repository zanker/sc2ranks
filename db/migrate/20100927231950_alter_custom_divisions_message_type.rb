class AlterCustomDivisionsMessageType < ActiveRecord::Migration
  def self.up
	change_column :custom_rankings, :message, :text
  end

  def self.down
	change_column :custom_rankings, :message, :string
  end
end
