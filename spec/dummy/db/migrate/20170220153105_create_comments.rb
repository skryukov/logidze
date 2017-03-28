class CreateComments < ActiveRecord::Migration
  def change
    create_table :comments do |t|
      t.text :content
      t.jsonb :log_data
      t.references :article, foreign_key: true

      t.timestamps null: false
    end
  end
end