class CreatePosts < ActiveRecord::Migration[7.0]
  def change
    create_table :posts do |t|
      t.references :user, null: false, foreign_key: true    
      t.integer :user_type
      t.datetime :pin_start_time
      t.datetime :pin_end_time
      t.boolean :is_pinned, default: false
      t.integer :pinned_position
      t.integer :pinned_tab
      t.integer :status
      t.string :tags, array: true, default: []
      t.integer :created_by_user_id
      t.string :content_type
      t.string :title
      t.string :url
      t.text :raw_content
      t.string :links, array: true, default: []
      t.integer :cached_votes_total, default: 0
      t.integer :cached_votes_up, default: 0
      t.integer :cached_votes_down, default: 0


      t.timestamps
    end
  end
end
