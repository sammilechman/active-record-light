require_relative 'db_connection'
require_relative '01_mass_object'
require 'active_support/inflector'

class MassObject
  def self.parse_all(results)
    results.map { |result| self.new(result) }
  end
end

class SQLObject < MassObject
  def self.columns
    @columns ||= begin
      cols = DBConnection.execute2("SELECT * FROM #{self.table_name}")[0]
      cols.each do |name|
        define_method(name) { self.attributes[name] }
        define_method("#{name}=") { |v| self.attributes[name] = v }
      end
      cols.map!(&:to_sym)
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || self.name.underscore.pluralize
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
      SELECT
      #{ table_name}.*
      FROM
      #{ table_name}
      SQL
    parse_all(results)
  end

  def self.find(id)
    results = DBConnection.execute(<<-SQL, id)
      SELECT
      #{self.table_name}.*
      FROM
      #{self.table_name}
      WHERE
      #{self.table_name}.id = ?
      SQL
    parse_all(results).first
  end

  def attributes
    @attributes ||= {}
  end

  def insert
    col_names = self.class.columns.join(", ")
    question_marks = ( ["?"] * self.class.columns.count ).join(", ")
    DBConnection.execute(<<-SQL, *attribute_values)
        INSERT INTO
        #{self.class.table_name} (#{col_names})
        VALUES
        (#{ question_marks })
        SQL
      self.id = DBConnection.last_insert_row_id
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      attr_name = attr_name.to_sym
      if self.class.columns.include?(attr_name)
        self.send("#{attr_name}=", value)
      else
        raise "unknown attribute '#{attr_name}'"
      end
    end
  end

  def save
    if self.id.nil?
      self.insert
    else
      self.update
    end

  end

  def update
    set_line = []
    self.class.columns.each do |x|
      set_line << ("#{x.to_sym} = ?")
    end
    DBConnection.execute(<<-SQL, *attribute_values, self.id)
      UPDATE
        #{self.class.table_name}
      SET
        #{ set_line.join(", ") }
      WHERE
        #{self.class.table_name}.id = ?
      SQL
  end

  def attribute_values
    self.class.columns.map { |attr| self.send(attr) }
  end
end