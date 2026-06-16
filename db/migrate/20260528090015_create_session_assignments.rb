class CreateSessionAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :session_assignments do |t|
      t.references :camp_session, null: false, foreign_key: true
      t.references :writer, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :session_assignments, [ :camp_session_id, :writer_id ], unique: true,
              name: "index_session_assignments_unique_per_session"
  end
end
