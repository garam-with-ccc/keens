class CreateCampSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :camp_sessions do |t|
      t.references :camp, null: false, foreign_key: true
      t.string :title
      t.string :room
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.timestamps
    end

    add_index :camp_sessions, [ :camp_id, :starts_at ]
  end
end
