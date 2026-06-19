class CreateRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :requests do |t|
      t.uuid :auth_bypass_id, null: false
      t.string :source_id, null: false
      t.string :source_app, null: false
      t.string :source_url
      t.string :source_title
      t.uuid :draft_content_id
      t.uuid :draft_auth_bypass_id
      t.string :draft_slug
      t.string :requester_name, null: false
      t.string :requester_email, null: false
      t.string :status, null: false, default: "new"
      t.json :previous_content
      t.json :current_content, null: false
      t.string :reason_for_change
      t.datetime :deadline

      t.timestamps
    end

    add_index :requests, :created_at
    add_index :requests, %i[source_app source_id created_at], unique: true, name: "index_requests_on_source_app_id_source_id_and_created_at"
  end
end
