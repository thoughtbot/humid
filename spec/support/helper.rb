require_relative "../../lib/humid"
require 'rails'
Rails.logger = Logger.new(STDOUT)

def build_path(path)
  File.expand_path("../testapp/app/assets/builds/#{path}", File.dirname(__FILE__))
end

def js_path(path)
  File.expand_path("../testapp/app/assets/javascript/#{path}", File.dirname(__FILE__))
end
