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

  class FileNotFound < StandardError
  end

  @@context = nil

  config_accessor :server_rendering_pack do
    "server_rendering.js"
  end

  config_accessor :use_source_map do
    false
  end

  config_accessor :raise_render_errors do
    true
  end

  config_accessor :logger do
    Logger.new(STDOUT)
  end

  config_accessor :context_options do
    {}
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

  def handle_stale_files
    if Webpacker.compiler.stale?
      Webpacker.compiler.compile
    end

    public_path = Webpacker.config.public_path
    server_rendering_pack = config.server_rendering_pack
    source_path = public_path.join(Webpacker.manifest.lookup(server_rendering_pack)[1..-1])
    filename = File.basename(source_path.to_s)

    if @@current_filename != filename
      dispose
      create_context
    end
  end

  def context
    if @@context && Webpacker.env.development?
      handle_stale_files
    end

    @@context
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

    webpack_source_file = Webpacker.manifest.lookup(config.server_rendering_pack)
    if webpack_source_file.nil?
      raise FileNotFound.new("Humid could not find a built pack for #{config.server_rendering_pack}")
    end

    if config.use_source_map
      webpack_source_map = Webpacker.manifest.lookup("#{config.server_rendering_pack}.map")
      map_path = public_path.join(webpack_source_map[1..-1])
      ctx.attach("readSourceMap", proc { File.read(map_path) })
    end

    source_path = public_path.join(webpack_source_file[1..-1])
    filename = File.basename(source_path.to_s)
    @@current_filename = filename
    ctx.eval(File.read(source_path), filename: filename)

    @@context = ctx
  end

  def render(*args)
    ActiveSupport::Notifications.instrument("render.humid") do
      context.call("__renderer", *args)
    rescue MiniRacer::RuntimeError => e
      message = ([e.message] + e.backtrace.filter {|x| x.starts_with? "JavaScript"}).join("\n")
      render_error = Humid::RenderError.new(message)

      if config.raise_render_errors
        raise render_error
      else
        config.logger.error(render_error.inspect)
        ""
      end
    end
  end
end

Humid::LogSubscriber.attach_to :humid
ActiveSupport.on_load(:action_controller) do
  include Humid::ControllerRuntime
end
