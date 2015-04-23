require_relative 'searchable'
require 'active_support/inflector'

class AssocOptions
  attr_accessor(
    :foreign_key,
    :class_name,
    :primary_key
  )

  def model_class
    self.class_name.constantize
  end

  def table_name
    self.model_class.table_name
  end
end

class BelongsToOptions < AssocOptions
  def initialize(name, options = {})

    self.foreign_key = (name.to_s.downcase.underscore + "_id").to_sym
    self.primary_key = :id
    @class_name = name.to_s.singularize.camelcase

    unless options.empty?
      options.each do |key, val|
        if self.instance_variables.include?("@#{key}".to_sym)
          self.send("#{key}=", val)
        end
      end
    end
  end

  def class_name
    @class_name
  end
end

class HasManyOptions < AssocOptions
  def initialize(name, self_class_name, options = {})

    self.foreign_key =
      (self_class_name.to_s.downcase.singularize.underscore + "_id").to_sym
    self.primary_key = :id
    @class_name = name.to_s.singularize.camelcase

    unless options.empty?
      options.each do |key, val|
        if self.instance_variables.include?("@#{key}".to_sym)
          self.send("#{key}=", val)
        end
      end
    end
  end

end

module Associatable

  def belongs_to(name, options = {})
    options = BelongsToOptions.new(name, options)

    define_method(name) do
      target_class = options.model_class
      target_id = send(options.foreign_key)
      target_class.where({options.primary_key => target_id}).first
    end

    assoc_options[name] = options
  end

  def has_many(name, options = {})
    options = HasManyOptions.new(name, self, options)

    define_method(name) do
      target_class = options.model_class
      target_id = send(options.primary_key)
      target_class.where({options.foreign_key => target_id})
    end
  end

  def assoc_options
    @assoc_options = {} if @assoc_options.nil?
    @assoc_options
  end

  def has_one_through(name, through_name, source_name)
    define_method(name) do
      through_options = self.class.assoc_options[through_name]
      source_options = through_name.to_s.capitalize.constantize.assoc_options[source_name]
      through_table = through_options.table_name
      source_table = source_options.table_name

      belongs_to_through_query = <<-SQL
        SELECT
          #{source_table}.*
        FROM
          #{through_table}
        JOIN
          #{source_table} ON #{through_table}.#{source_options.foreign_key}
          = #{source_table}.#{source_options.primary_key}
        WHERE
          #{through_table}.#{source_options.primary_key} = ?
      SQL

      source_options.model_class.parse_all(
        DBConnection.execute(
          belongs_to_through_query, self.send(through_name).send(
            through_options.primary_key))
      ).first
    end
  end
end

class SQLObject
  extend Associatable
end
