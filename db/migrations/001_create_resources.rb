Sequel.migration do
  change do
    create_table(:resources) do
      column :id, "uuid", primary_key: true, default: Sequel.lit("gen_random_uuid()")
      String :session_id, null: false
      String :resource_type, null: false
      String :resource_id, null: false
      column :resource, "jsonb", null: false
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :expired_at, null: false

      index [:session_id, :resource_type, :resource_id], unique: true, name: :idx_resource_lookup
      index :expired_at
    end
  end
end
