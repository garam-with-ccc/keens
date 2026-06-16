class CreateOrganizerInvites < ActiveRecord::Migration[8.1]
  def change
    create_table :organizer_invites do |t|
      t.references :user, null: false, foreign_key: true
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.timestamps
    end

    add_index :organizer_invites, :token_digest, unique: true
    add_index :organizer_invites, :expires_at
  end
end
