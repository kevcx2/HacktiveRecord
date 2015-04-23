require_relative 'db_connection'
require 'active_support/inflector'

class SQLObject
  def self.columns
    table = DBConnection::execute2(<<-SQL)
      SELECT
      *
      FROM
      #{table_name}
    SQL
    table.first.map(&:to_sym)
  end

  def self.finalize!
    columns.each do |col|
      define_method(col) do
        attributes[col]
      end
      define_method("#{col}=") do |arg|
        attributes[col] = arg
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    if @table_name
      @table_name
    else
      @table_name = self.to_s.tableize
    end
  end

  def self.all
    all_query = <<-SQL
      SELECT
        #{table_name}.*
      FROM
        #{table_name}
    SQL

    parse_all(DBConnection.execute(all_query))

  end

  def self.parse_all(results)
    all_rows = []
    results.each do |row|
      all_rows << self.new(row)
    end
    all_rows
  end

  def self.find(id)
    find_query = <<-SQL
      SELECT
        #{table_name}.*
      FROM
        #{table_name}
      WHERE
        #{table_name}.id = #{id}
    SQL
    found_object = DBConnection.execute(find_query)[0]
    return nil unless found_object
    self.new(found_object)
  end

  def initialize(params = {})
    params.each do |attr_name, val|
      attr_name = attr_name.to_sym
      unless self.class.columns.include?(attr_name)
        raise "unknown attribute \'#{attr_name}\'"
      end
      self.send("#{attr_name}=", val)
    end
  end

  def attributes
    if @attributes
      @attributes
    else
      @attributes = {}
    end
  end

  def attribute_values
    self.class.columns.map {|col| self.send"#{col}"}
  end

  def insert
    num_cols = self.class.columns.length
    col_names = self.class.columns.join(', ')
    q_marks = (["?"] * num_cols).join(', ')

    DBConnection.execute(<<-SQL, [*attribute_values])
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{q_marks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update

    set_str = []
    self.class.columns.each do |col|
      set_str << "#{col} = ?"
    end
    set_str = set_str.join(', ')

    DBConnection.execute(<<-SQL, [*(attribute_values << self.id)])
      UPDATE
        #{self.class.table_name}
      SET
        #{set_str}
      WHERE
        id = ?
    SQL

  end

  def save
    if self.id.nil?
      self.insert
    else
      self.update
    end
  end

end
