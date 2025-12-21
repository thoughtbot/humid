require "mini_racer"
require "logger"
require "active_support"
require "active_support/core_ext"
require "humid/log_subscriber"
require "humid/controller_runtime"
require "humid/version"

class Humid
  @@context = nil

  class RenderError < StandardError
  end

  class FileNotFound < StandardError
  end
  
  class_attribute :config

  self.config = ActiveSupport::OrderedOptions.new.merge({
    raise_render_errors: true,
    context_options: {},
  })

  class << self
    def configure
      yield config
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
      @@context
    end

    def dispose
      if @@context
        @@context.dispose
        @@context = nil
      end
    end

    def create_context
      ctx = MiniRacer::Context.new(**config.context_options)

      if logger
        ctx.attach("console.log", proc { |err| logger.debug(err.to_s) })
        ctx.attach("console.info", proc { |err| logger.info(err.to_s) })
        ctx.attach("console.error", proc { |err| logger.error(err.to_s) })
        ctx.attach("console.warn", proc { |err| logger.warn(err.to_s) })
      end

      js = ""
      js << remove_functions
      js << renderer
      ctx.eval(js)

      source_path = config.application_path
      map_path = config.source_map_path

      if map_path
        ctx.attach("readSourceMap", proc { File.read(map_path) })
      end

      filename = File.basename(source_path.to_s)
      @@current_filename = filename
      ctx.eval(File.read(source_path), filename: filename)

      @@context = ctx
    end

    def render(*args)
      ActiveSupport::Notifications.instrument("render.humid") do
        context.call("__renderer", *args)
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
  end
end

Humid::LogSubscriber.attach_to :humid
ActiveSupport.on_load(:action_controller) do
  include Humid::ControllerRuntime
end
