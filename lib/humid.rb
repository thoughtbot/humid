require "mini_racer"
require "logger"
require "active_support"
require "active_support/core_ext"
require "humid/log_subscriber"
require "humid/controller_runtime"
require "humid/version"
require "humid/renderer"

class Humid
  include ActiveSupport::Configurable

  class RenderError < StandardError; end

  class FileNotFound < StandardError; end

  config_accessor :application_path
  config_accessor :source_map_path
  config_accessor :raise_render_errors, default: true
  config_accessor :logger, default: Logger.new($stdout)

  class << self
    delegate :use_context, :render, :context, :dispose, to: Renderer
  end
end

Humid::LogSubscriber.attach_to :humid
ActiveSupport.on_load(:action_controller) do
  include Humid::ControllerRuntime
end
