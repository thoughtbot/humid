require "mini_racer"
require "logger"
require "webpacker"
require "active_support"
require "active_support/core_ext"
require "humid/log_subscriber"
require "humid/controller_runtime"
require "humid/version"

module Humid
  extend self
  include ActiveSupport::Configurable

  class RenderError < StandardError
  end

  config_accessor :server_rendering_file do
    "server_rendering.js"
  end

  config_accessor :use_source_map do
    false
  end

  config_accessor :logger do
    Logger.new(STDOUT)
  end

  config_accessor :context_options do
    {
      timeout: 1000,
      ensure_gc_after_idle: 2000
    }
  end

  def remove_functions
    <<~JS
      delete this.setTimeout;
      delete this.setInterval;
      delete this.clearTimeout;
      delete this.clearInterval;
      delete this.setImmediate;
      delete this.clearImmediate;
    JS
  end

  def logger
    config.logger
  end

  def renderer
    <<~JS
      var __renderer;
      function setHumidRenderer(fn) {
        __renderer = fn;
      }
    JS
  end

  def context
    if @@context && Webpacker.env.development? && Webpacker.compiler.stale?
      Webpacker.compiler.compile
      dispose
      create_context
    else
      @@context
    end
  end

  def dispose
    if @@context
      @@context.dispose
      @@context = nil
    end
  end

  def create_context
    ctx = MiniRacer::Context.new(config.context_options)
    ctx.attach("console.log", proc { |err| logger.debug(err.to_s) })
    ctx.attach("console.info", proc { |err| logger.info(err.to_s) })
    ctx.attach("console.error", proc { |err| logger.error(err.to_s) })
    ctx.attach("console.warn", proc { |err| logger.warn(err.to_s) })

    js = ""
    js << remove_functions
    js << renderer
    ctx.eval(js)

    public_path = Webpacker.config.public_path
    server_rendering_file = config.server_rendering_file
    server_rendering_map = "#{config.server_rendering_file}.map"

    source_path = public_path.join(Webpacker.manifest.lookup(server_rendering_file)[1..-1])
    map_path = public_path.join(Webpacker.manifest.lookup(server_rendering_map)[1..-1])

    filename = File.basename(source_path.to_s)
    ctx.eval(File.read(source_path), filename: filename)

    if config.use_source_map
      ctx.attach("readSourceMap", proc { File.read(map_path) })
    end

    @@context = ctx
  end

  def render(*args)
    ActiveSupport::Notifications.instrument("render.humid") do
      context.call("__renderer", *args)
    rescue MiniRacer::RuntimeError => e
      message = ([e.message] + e.backtrace.filter {|x| x.starts_with? "JavaScript"}).join("\n")
      raise Humid::RenderError.new(message)
    end
  end
end

Humid::LogSubscriber.attach_to :humid
ActiveSupport.on_load(:action_controller) do
  include Humid::ControllerRuntime
end
