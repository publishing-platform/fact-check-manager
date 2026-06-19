class CreateResponses < ActiveRecord::Migration[8.1]
  def change
    create_table :responses do |t|
      t.text :body
      t.boolean :accepted

      t.references :user, null: false, index: true, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :request, null: false, index: { unique: true }, foreign_key: { to_table: :requests, on_delete: :restrict }

      t.timestamps
    end
  end
end
