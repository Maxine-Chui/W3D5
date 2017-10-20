require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    return @columns if @columns
    col = DBConnection.execute2(<<-SQL)
      SELECT
      *
      FROM
      "#{self.table_name}"
    SQL
    col = col.first.map! { |el| el.to_sym }
    @columns = col
  end

  def self.finalize!
    columns.each do |col|
      define_method(col) do
        attributes[col]
      end
      define_method("#{col}=") do |val|
        attributes[col] = val
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= self.name.underscore.pluralize
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
      SELECT
      *
      FROM
      #{table_name}
    SQL
    self.parse_all(results)
  end

  def self.parse_all(results)
    results.map { |result| self.new(result) }
  end

  def self.find(id)
    results = DBConnection.execute(<<-SQL, id)
      SELECT
      *
      FROM
      #{table_name}
      WHERE
      id = ?
    SQL
    parse_all(results).first
  end

  def initialize(params = {})
    params.each do |attr_name, val|
      attr_name = attr_name.to_sym
      raise "unknown attribute '#{attr_name}'" if !self.class.columns.include?(attr_name)
      self.send("#{attr_name}=", val)
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map { |column| send(column) }
  end

  def insert
    col_names = self.class.columns.drop(1).join(',')
    question_marks = (["?"] * (attribute_values.count - 1)).join(',')
    DBConnection.execute(<<-SQL, *attribute_values.drop(1))
      INSERT INTO
      #{self.class.table_name} (#{col_names})
      VALUES
      (#{question_marks})
    SQL
    self.id = DBConnection.last_insert_row_id
  end

  def update
    col_names = self.class.columns.drop(1).map {|col| "#{col} = ?"}.join(',')
    DBConnection.execute(<<-SQL, *attribute_values.drop(1), id)
    UPDATE
      #{self.class.table_name}
    SET
      #{col_names}
    WHERE
      id = ?
    SQL
  end

  def save
    if id.nil?
      insert
    else
      update
    end
  end
end
