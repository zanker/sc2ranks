class AddSessionTokenToCustomRankings < ActiveRecord::Migration
  def self.up
    add_column :custom_rankings, :session_token, :string
  end

  def self.down
    remove_column :custom_rankings, :session_token
  end
end
