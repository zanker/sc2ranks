class CreateCustomRankingBans < ActiveRecord::Migration
  def self.up
    create_table :custom_ranking_bans do |t|
      t.string :ip_address
      t.integer :custom_ranking_id
      t.datetime :updated_at
    end
	
	add_index :custom_ranking_bans, :custom_ranking_id
  end

  def self.down
    drop_table :custom_ranking_bans
  end
end
