require_relative 'db_connection'
require_relative 'sql_object'

module Searchable
  def where(params)

    where_str = []
    params.keys.each do |key|
      where_str << "#{key} = ?"
    end
    where_str = where_str.join(' AND ')

    found_row = DBConnection.execute(<<-SQL, [*params.values])
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        #{where_str}
    SQL

    found_objects = []
    found_row.each do |row|
      found_objects << self.new(row)
    end
    found_objects
  end
end

class SQLObject
  # Mixin Searchable
  extend Searchable
end
