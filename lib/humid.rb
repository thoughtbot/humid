require "mini_racer"
require "logger"
require "active_support"
require "active_support/core_ext"
require "humid/log_subscriber"
require "humid/controller_runtime"
require "humid/version"

module Humid
  class RenderError < StandardError
  end

  class FileNotFound < StandardError
  end

  mattr_accessor :config

  self.config = ActiveSupport::OrderedOptions.new.merge({
    raise_render_errors: true,
    log_formatter: proc { |_level, message, *_rest| message },
  })

  extend self
  
  def configure
    yield self.config
  end

  def prepare(ctx, options = {})
    effective_config = config.merge(options)
    logger = effective_config.logger
    log_formatter = effective_config.log_formatter

    if logger
      fmt = log_formatter || proc { |_level, message, *_rest| message }
      ctx.attach("console.log", proc { |*args| logger.debug(fmt.call(:debug, *args)) })
      ctx.attach("console.info", proc { |*args| logger.info(fmt.call(:info, *args)) })
      ctx.attach("console.error", proc { |*args| logger.error(fmt.call(:error, *args)) })
      ctx.attach("console.warn", proc { |*args| logger.warn(fmt.call(:warn, *args)) })
    end

    js = ""
    js << remove_functions
    js << renderer
    ctx.eval(js)

    source_path = effective_config.application_path
    map_path = effective_config.source_map_path

    if map_path
      ctx.attach("readSourceMap", proc { File.read(map_path) })
    end

    filename = File.basename(source_path.to_s)
    ctx.eval(File.read(source_path), filename: filename)

    ctx
  end

  def render(ctx, *args)
    ActiveSupport::Notifications.instrument("render.humid") do
      ctx.call("__renderer", *args)
    rescue MiniRacer::RuntimeError => e
      message = ([e.message] + e.backtrace.filter { |x| x.starts_with? "JavaScript" }).join("\n")
      render_error = Humid::RenderError.new(message)

      if config.raise_render_errors
        raise render_error
      else
        config.logger.error(render_error.inspect)
        ""
      end
    end
  end

  private
  
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

  def renderer
    <<~JS
      var __renderer;
      function setHumidRenderer(fn) {
        __renderer = fn;
      }
    JS
  end
end

Humid::LogSubscriber.attach_to :humid
ActiveSupport.on_load(:action_controller) do
  include Humid::ControllerRuntime
end
