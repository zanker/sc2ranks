class CreateCustomRankingLogs < ActiveRecord::Migration
  def self.up
    create_table :custom_ranking_logs do |t|
	  t.integer :custom_ranking_id
      t.string :ip_address
	  t.boolean :was_added
      t.text :character_ids
      t.datetime :updated_at
    end
	
	add_index :custom_ranking_logs, :custom_ranking_id
  end

  def self.down
    drop_table :custom_ranking_logs
  end
end
