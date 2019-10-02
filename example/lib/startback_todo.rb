require 'startback'
require 'startback/web/catch_all'
require 'startback/web/shield'
require 'startback/web/api'
require 'startback/web/health_check'

module StartbackTodo

  require_relative 'startback_todo/errors'
  require_relative 'startback_todo/database'
  require_relative 'startback_todo/operation'
  require_relative 'startback_todo/app'
  require_relative 'startback_todo/api'

  DB = Database.new

end # module StartbackTodo
