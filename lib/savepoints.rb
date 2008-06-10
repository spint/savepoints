module ActiveRecord
  module ConnectionAdapters
    AbstractAdapter.class_eval do
      # Reimplement transaction and handle savepoints
      def transaction(start_db_transaction = true, savepoint_number = 1)
        transaction_open = false
        savepoint_open = false
        begin
          if block_given?
            if start_db_transaction
              if savepoint_number == 1
                begin_db_transaction
              else
                if create_savepoint(savepoint_number)
                  savepoint_open = true
                end
              end
              transaction_open = true
            end
            yield
          end
        rescue Exception => database_transaction_rollback
          if transaction_open
            transaction_open = false
            unless savepoint_open
              rollback_db_transaction
            else
              savepoint_open = false
              rollback_to_savepoint(savepoint_number)
            end
          end
          raise unless database_transaction_rollback.is_a? ActiveRecord::Rollback
        end
      ensure
        if transaction_open
          begin
            unless savepoint_open
              commit_db_transaction
            else
              release_savepoint(savepoint_number)
            end
          rescue Exception => database_transaction_rollback
            unless savepoint_open
              rollback_db_transaction
            else
              rollback_to_savepoint(savepoint_number)
            end
            raise
          end
        end
      end
      
      def savepoint_name(savepoint_number)
        "rails_nested_transaction_#{savepoint_number}"
      end
    end
    
    if defined?(ActiveRecord::ConnectionAdapters::MysqlAdapter)
      class MysqlAdapter < AbstractAdapter
        def create_savepoint(savepoint_number)
          execute("SAVEPOINT #{savepoint_name(savepoint_number)}")
          true
        rescue Exception
          # Savepoints are not supported
        end
        
        def rollback_to_savepoint(savepoint_number)
          execute("ROLLBACK TO SAVEPOINT #{savepoint_name(savepoint_number)}")
        rescue Exception
          # Savepoints are not supported
        end
        
        def release_savepoint(savepoint_number)
          execute("RELEASE SAVEPOINT #{savepoint_name(savepoint_number)}")
        rescue Exception
          # Savepoints are not supported
        end
      end
    end
    
    if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
      class PostgreSQLAdapter < AbstractAdapter
        def create_savepoint(savepoint_number)
          execute("SAVEPOINT #{savepoint_name(savepoint_number)}")
          true
        rescue Exception
          # Savepoints are not supported
        end
        
        def rollback_to_savepoint(savepoint_number)
          execute("ROLLBACK TO SAVEPOINT #{savepoint_name(savepoint_number)}")
        rescue Exception
          # Savepoints are not supported
        end
        
        def release_savepoint(savepoint_number)
          execute("RELEASE SAVEPOINT #{savepoint_name(savepoint_number)}")
        rescue Exception
          # Savepoints are not supported
        end
      end
    end
  end
  
  class Base
    class << self
      def transaction(options = {}, &block)
        options.assert_valid_keys :force
        
        increment_open_transactions
        
        begin
          connection.transaction((options[:force] == true) || Thread.current["start_db_transaction"], Thread.current["open_transactions"], &block)
        ensure
          decrement_open_transactions
        end
      end

      private
        def increment_open_transactions #:nodoc:
          open = Thread.current["open_transactions"] ||= 0
          
          if open.zero? || (open == 1 && Thread.current["transactional_fixtures"])
            Thread.current["start_db_transaction"] = true
          else
            Thread.current["start_db_transaction"] = false
          end
          
          Thread.current["open_transactions"] = open + 1
        end
        
        def decrement_open_transactions #:nodoc:
          Thread.current["open_transactions"] -= 1
        end
    end
  end
end

require "active_record/fixtures"

module Test
  module Unit
    class TestCase
      # Add Thread.current["transactional_fixtures"] so a savepoint
      # will automatically be used by transactions inside the tests, even
      # though :force => true is not defined.
      def setup_fixtures
        return unless defined?(ActiveRecord) && !ActiveRecord::Base.configurations.blank?

        if pre_loaded_fixtures && !use_transactional_fixtures
          raise RuntimeError, 'pre_loaded_fixtures requires use_transactional_fixtures'
        end

        @fixture_cache = {}

        # Load fixtures once and begin transaction.
        if use_transactional_fixtures?
          if @@already_loaded_fixtures[self.class]
            @loaded_fixtures = @@already_loaded_fixtures[self.class]
          else
            load_fixtures
            @@already_loaded_fixtures[self.class] = @loaded_fixtures
          end
          Thread.current["transactional_fixtures"] = true
          ActiveRecord::Base.send :increment_open_transactions
          ActiveRecord::Base.connection.begin_db_transaction
        # Load fixtures for every test.
        else
          Fixtures.reset_cache
          @@already_loaded_fixtures[self.class] = nil
          load_fixtures
        end

        # Instantiate fixtures for every test if requested.
        instantiate_fixtures if use_instantiated_fixtures
      end
      
      def teardown_fixtures
        return unless defined?(ActiveRecord) && !ActiveRecord::Base.configurations.blank?

        unless use_transactional_fixtures?
          Fixtures.reset_cache
        end

        # Rollback changes if a transaction is active.
         if use_transactional_fixtures?
          if Thread.current['open_transactions'] != 0
            ActiveRecord::Base.connection.rollback_db_transaction
            Thread.current['open_transactions'] = 0
          end
          Thread.current["transactional_fixtures"] = false
        end
        ActiveRecord::Base.verify_active_connections!
      end
    end
  end
end

