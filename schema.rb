require 'sequel'

module Schema
  def self.db(name)
    url = ENV["HEROKU_POSTGRESQL_#{name.upcase}_URL"]
    Sequel.connect url
  end

  def self.recreate(name)
    db = db(name)
    db.create_table!(:colors) do
      primary_key :id
      String :color
    end
  end
end
