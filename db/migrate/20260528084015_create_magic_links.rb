class CreateMagicLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :magic_links do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.string :requested_ip
      t.string :requested_user_agent
      t.timestamps
    end

    add_index :magic_links, :token_digest, unique: true
    add_index :magic_links, :expires_at
  end
end
