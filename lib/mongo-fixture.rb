# Third-party
require "fast/fast"
require "symbolmatrix"
require "mongo"

require "mongo-fixture/version"
require "mongo-fixture/inserter"

module Mongo

  # Fixture managing class for MongoDB
  class Fixture
    ## Class methods
    
    # Returns the current path to the fixtures folder
    def self.path
      @@path ||= "test/fixtures"
    end

    ## Instance methods
    
    # Initializes the fixture handler
    # Accepts optionally a symbol as a reference to the fixture
    # and a Mongo::DB connection
    def initialize fixture = nil, connection = nil, option_push = true
      load fixture if fixture
      
      @connection = connection if connection
      @inserter = Inserter.new self
      push if fixture && connection && option_push
    end    
    
    # Loads the fixture files into this instance
    def load fixture
      raise LoadingFixtureIllegal, "A check has already been made, loading a different fixture is illegal" if @checked
      
      Fast.dir("#{fixtures_path}/#{fixture}").files.to.symbols.each do |file|
        @data ||= {}
        @data[file] = SymbolMatrix.new "#{fixtures_path}/#{fixture}/#{file}.yaml"
      end
    end
        
    # Returns the current fixtures path where Sequel::Fixtures looks for fixture folders
    def fixtures_path
      Mongo::Fixture.path
    end    
    
    # Forces the check to pass. Dangerous!
    def force_checked!
      @checked = true
    end
    
    # Returns the SymbolMatrix with the data referring to that table
    def [] reference
      @data[reference]
    end
    
    # Method missing, for enabling discovery of tables
    def method_missing s, *args
      return @data[s] if @data && @data.has_key?(s)
      return super
    end
    
    # Returns the current database connection
    attr_reader :connection   
    
    # Sets the connection. Raises an ChangingConnectionIllegal exception if this fixture has already been checked
    def connection= the_connection
      raise ChangingConnectionIllegal, "A check has already been performed, changing the connection now is illegal" if @checked
      @connection = the_connection
    end
    
    # Returns the current data collection
    attr_reader :data
    
    # Assures that the collections are empty before proceeding
    def check
      return @checked if @checked # If already checked, it's alright

      raise MissingFixtureError, "No fixture has been loaded, nothing to check" unless @data
      raise MissingConnectionError, "No connection has been provided, impossible to check" unless @connection
      
      @data.each_key do |collection|
        raise CollectionsNotEmptyError, "The collection '#{collection}' is not empty, all collections should be empty prior to testing" if @connection[collection].count != 0
      end
      return @checked = true
    end
    
    # Inserts the fixture data into the corresponding collections
    def push
      check
      
      data.each_key do |collection|
        @inserter.insert_data_for collection
      end
#      @data.each do |collection, matrix|
#        unless @inserter.data_was_inserted_in? collection
#          matrix.each do |element, values|
#            begin
#                @connection[collection].insert @inserter.simplify values.to_hash
#            rescue MissingProcessedValueError => m
#              rollback
#              raise MissingProcessedValueError, "In record '#{element}' to be inserted into '#{collection}', the processed value of field '#{m.field}' is missing, aborting"
#            end
#          end
#          @inserted << collection
#        end
#      end
    end
        
    # Empties the collections, only if they were empty to begin with
    def rollback
      begin
        check
        
        @data.each_key do |collection|
          @connection[collection].drop
        end
      rescue CollectionsNotEmptyError => e
        raise RollbackIllegalError, "The collections weren't empty to begin with, rollback aborted."
      end
    end
    
    class LoadingFixtureIllegal < StandardError; end
    class CollectionsNotEmptyError < StandardError; end
    class MissingFixtureError < StandardError; end
    class MissingConnectionError < StandardError; end
    class ChangingConnectionIllegal < StandardError; end
    class RollbackIllegalError < StandardError; end
    class MissingProcessedValueError < StandardError
      attr_accessor :field
      def initialize message, field = nil
        @field = field
        super message
      end
    end    
    

  end
end
