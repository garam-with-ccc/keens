class CreateCampMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :camp_memberships do |t|
      t.references :camp, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    add_index :camp_memberships, [ :camp_id, :user_id ], unique: true,
              name: "index_camp_memberships_unique_per_camp"
  end
end
