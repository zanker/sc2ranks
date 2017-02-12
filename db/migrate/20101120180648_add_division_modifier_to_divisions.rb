class AddDivisionModifierToDivisions < ActiveRecord::Migration
  def self.up
    add_column :divisions, :modifier, :integer
  end

  def self.down
    remove_column :divisions, :modifier
  end
end
