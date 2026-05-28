class CreateWriterProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :writer_profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :display_name
      t.string :pronouns
      t.string :pro_affiliation
      t.timestamps
    end
  end
end
