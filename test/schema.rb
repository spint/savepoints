ActiveRecord::Schema.define :version => 0 do
  create_table :people, :force => true do |t|
    t.column :name, :string
    t.column :happy, :boolean
  end
end
