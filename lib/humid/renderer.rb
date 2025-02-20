class Humid
  class Renderer
    cattr_accessor :context, instance_writer: false, instance_reader: false

    class << self
      def use_context(ctx)
        self.context = ctx

        ctx.attach("console.log", proc { |err| logger.debug(err.to_s) })
        ctx.attach("console.info", proc { |err| logger.info(err.to_s) })
        ctx.attach("console.error", proc { |err| logger.error(err.to_s) })
        ctx.attach("console.warn", proc { |err| logger.warn(err.to_s) })

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
        ctx.eval(File.read(source_path), filename: filename)
      end

      def dispose
        if context
          context.dispose
          self.context = nil
        end
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
            logger.error(render_error.inspect)
            ""
          end
        end
      end

      def logger
        config.logger
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

      def config
        Humid.config
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
  end
end
