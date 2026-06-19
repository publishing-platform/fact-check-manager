class CreateCollaborations < ActiveRecord::Migration[8.1]
  def change
    create_table :collaborations do |t|
      t.string :role

      t.references :user, null: false, index: true, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :request, null: false, index: true, foreign_key: { to_table: :requests, on_delete: :restrict }

      t.timestamps
    end

    add_index :collaborations, %i[user_id request_id], unique: true
  end
end
