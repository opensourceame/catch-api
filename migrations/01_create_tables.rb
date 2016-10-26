Sequel.migration do
  up do

    create_table(:users) do
      primary_key :id, type: Bignum
      DateTime  :created_at
      DateTime  :updated_at
      DateTime  :last_move_at
      Bignum    :facebook_id
      String    :type
      Integer   :turn,                          default: 0
      String    :first_name,        size: 50,                         null: false
      String    :last_name,         size: 50
      String    :status,            size: 20
      String    :gender,            size: 10,   default: 'unknown'
      String    :phone,             size: 20
      String    :email,             size: 150
      String    :transport
      String    :location
      Integer   :money,                         default: 0
      Integer   :bike_tokens,                   default: 0
      Integer   :pedalo_tokens,                 default: 0
      Integer   :bus_tokens,                    default: 0
      Integer   :tram_tokens,                   default: 0
      String    :picture_url
    end

    create_table(:events) do
      primary_key :id, type: Bignum
      DateTime  :created_at
      DateTime  :updated_at
      Integer   :user_id
      String    :type
      String    :event
      String    :description
    end
  end

  down do
    drop_table(:locations)
    drop_table(:users)
  end

end
