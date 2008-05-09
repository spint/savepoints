require File.expand_path(File.dirname(__FILE__) +  '/abstract_unit')

class NestedTransactionsTest < Test::Unit::TestCase
  fixtures :people
  
  def test_force_savepoint_in_nested_transaction
    Person.transaction do
      people(:jonathan).update_attributes!(:happy => true)
      people(:david).update_attributes!(:happy => true)
      
      begin
        Person.transaction :force => true do
          people(:jonathan).update_attributes!(:happy => false)
          raise "error"
        end
      rescue
      end
    end

    assert Person.find(1).happy?
    assert Person.find(2).happy?
  end

  def test_no_savepoint_in_nested_transaction_without_force
    Person.transaction do
      people(:jonathan).update_attributes!(:happy => true)
      people(:david).update_attributes!(:happy => true)
      
      begin
        Person.transaction do
          people(:jonathan).update_attributes!(:happy => false)
          raise "error"
        end
      rescue
      end
    end

    assert !Person.find(1).happy?
    assert Person.find(2).happy?
  end
  
  def test_automatic_savepoint_in_outer_fixture_transaction
    people(:jonathan).reload
    
    assert_savepoints 1 do
      Person.transaction do
        assert_savepoints 0 do
          Person.transaction do
          end
        end
      end
    end
    
    assert_savepoints 1 do
      Person.transaction do
      end
    end
  end
  
 private
  def assert_savepoints(number, &block)
    assert_difference("ActiveRecord::Base.connection.savepoint_count", number, &block)
  end
end

