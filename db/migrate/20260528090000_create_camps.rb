class CreateCamps < ActiveRecord::Migration[8.1]
  def change
    create_table :camps do |t|
      t.string :name, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.text :brief
      t.string :target_artist
      t.references :organizer, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :camps, [ :organizer_id, :start_date ]
  end
end
