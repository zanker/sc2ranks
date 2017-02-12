class CreateCustomRankingCharacters < ActiveRecord::Migration
  def self.up
    create_table :custom_ranking_characters do |t|
      t.integer :character_id
      t.integer :custom_ranking_id
    end
	
	add_index :custom_ranking_characters, :character_id
	add_index :custom_ranking_characters, :custom_ranking_id
  end

  def self.down
    drop_table :custom_ranking_characters
  end
end
