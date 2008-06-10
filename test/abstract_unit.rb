ENV['RAILS_ENV'] = 'test'
require 'test/unit'

begin
  require File.dirname(__FILE__) + '/../../../../config/boot'
  Rails::Initializer.run
rescue LoadError
  require 'rubygems'
  require 'activerecord'
end

ActiveRecord::Base.configurations = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + '/debug.log')
ActiveRecord::Base.establish_connection(ENV['DB'] || 'mysql')

load(File.dirname(__FILE__) + '/schema.rb')

require File.expand_path(File.dirname(__FILE__) + '/../lib/savepoints')

Test::Unit::TestCase.fixture_path = File.dirname(__FILE__) + "/fixtures/"
Dependencies.load_paths.insert(0, Test::Unit::TestCase.fixture_path)

class Test::Unit::TestCase
  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = false
end

ActiveRecord::Base.connection.class.class_eval do
  cattr_accessor :savepoint_count
  self.savepoint_count = 0
  
  def execute_with_counting(sql, name = nil, &block)
    self.savepoint_count += 1 if sql =~ /^\s*savepoint/i
    execute_without_counting(sql, name, &block)
  end
  
  alias_method_chain :execute, :counting
end

