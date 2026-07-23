require_relative "./support/helper"

RSpec.describe "Humid" do
  describe "prepare" do
    it "prepares a context with initial js" do
      ctx = MiniRacer::Context.new
      result = Humid.prepare(ctx, application_path: js_path("simple.js"))

      expect(result).to be_kind_of(MiniRacer::Context)
      expect(result).to equal(ctx)
    end

    it "marks the context as humid_prepared" do
      ctx = MiniRacer::Context.new
      expect(ctx).not_to respond_to(:humid_prepared?)

      Humid.prepare(ctx, application_path: js_path("simple.js"))

      expect(ctx.humid_prepared?).to be true
    end

    context "When the file can not be found" do
      it "raises" do
        ctx = MiniRacer::Context.new

        expect {
          Humid.prepare(ctx, application_path: js_path("does_not_exist.js"))
        }.to raise_error(Errno::ENOENT)
      end
    end

    it "does not have timeouts, immediates, and intervals" do
      ctx = MiniRacer::Context.new
      Humid.prepare(ctx, application_path: js_path("simple.js"))

      expect {
        ctx.eval("setTimeout()")
      }.to raise_error(MiniRacer::RuntimeError, "ReferenceError: setTimeout is not defined")
      expect {
        ctx.eval("setInterval()")
      }.to raise_error(MiniRacer::RuntimeError, "ReferenceError: setInterval is not defined")
      expect {
        ctx.eval("clearTimeout()")
      }.to raise_error(MiniRacer::RuntimeError, "ReferenceError: clearTimeout is not defined")
      expect {
        ctx.eval("setImmediate()")
      }.to raise_error(MiniRacer::RuntimeError, "ReferenceError: setImmediate is not defined")
      expect {
        ctx.eval("clearImmediate()")
      }.to raise_error(MiniRacer::RuntimeError, "ReferenceError: clearImmediate is not defined")
    end

    it "proxies to Rails logger" do
      ctx = MiniRacer::Context.new
      logger = Logger.new($stdout)
      Humid.prepare(ctx, application_path: js_path("simple.js"), logger: logger)

      expect(logger).to receive(:info).with("hello")
      ctx.eval("console.info('hello')")
    end

    it "passes multiple console args to the log_formatter" do
      ctx = MiniRacer::Context.new
      logger = Logger.new($stdout)
      log_formatter = proc { |level, message, *rest|
        parts = [message]
        parts += rest.map { |a| a.is_a?(String) ? a : a.inspect }
        parts.join("\n")
      }

      Humid.prepare(ctx,
        application_path: js_path("simple.js"),
        logger: logger,
        log_formatter: log_formatter
      )

      expected_hash = {"path" => "notes.0", "code" => "type"}.inspect
      expect(logger).to receive(:error).with("[Error] validation failed\n#{expected_hash}")
      ctx.eval('console.error("[Error] validation failed", {path: "notes.0", code: "type"})')
    end

    it "passes the log level to the log_formatter" do
      ctx = MiniRacer::Context.new
      logger = Logger.new($stdout)

      received_level = nil
      log_formatter = proc { |level, message, *rest|
        received_level = level
        message
      }

      Humid.prepare(ctx,
        application_path: js_path("simple.js"),
        logger: logger,
        log_formatter: log_formatter
      )

      allow(logger).to receive(:warn)
      ctx.eval('console.warn("test")')

      expect(received_level).to eq(:warn)
    end

    it "allows log_formatter to raise errors" do
      ctx = MiniRacer::Context.new
      logger = Logger.new($stdout)
      log_formatter = proc { |level, message, *rest|
        raise Humid::RenderError, message if message.include?("validation failed")
        message
      }

      Humid.prepare(ctx,
        application_path: js_path("simple.js"),
        logger: logger,
        log_formatter: log_formatter
      )

      expect {
        ctx.eval('console.error("[Superglue] Content validation failed")')
      }.to raise_error(Humid::RenderError, "[Superglue] Content validation failed")
    end

    it "uses default log_formatter when none is configured" do
      ctx = MiniRacer::Context.new
      logger = Logger.new($stdout)

      Humid.prepare(ctx,
        application_path: js_path("simple.js"),
        logger: logger,
        log_formatter: nil
      )

      expect(logger).to receive(:error).with("hello")
      ctx.eval("console.error('hello')")
    end

    it "does not set the logger if none is configured" do
      ctx = MiniRacer::Context.new
      Humid.prepare(ctx, application_path: js_path("simple.js"))

      expect {
        ctx.eval("console.log('hello')")
      }.not_to raise_error
    end
  end

  describe "render" do
    it "returns a js output" do
      ctx = MiniRacer::Context.new
      Humid.prepare(ctx, application_path: js_path("simple.js"))

      expect(Humid.render(ctx)).to eql("hello")
    end

    it "applys args to the func" do
      ctx = MiniRacer::Context.new
      Humid.prepare(ctx, application_path: js_path("args.js"))

      args = ["a", 1, 2, [], {}]

      expect(Humid.render(ctx, *args)).to eql({"0" => "a", "1" => 1, "2" => 2, "3" => [], "4" => {}})
    end

    it "can use source maps to see errors" do
      system("yarn run build")
      ctx = MiniRacer::Context.new
      Humid.prepare(ctx,
        application_path: build_path("reporting.js"),
        source_map_path: build_path("reporting.js.map")
      )

      expect {
        Humid.render(ctx)
      }.to raise_error { |error|
        expect(error).to be_a(Humid::RenderError)
        message = <<~MSG
          Error: ^^ Look! These stack traces map to the actual source code :)
          JavaScript at throwSomeError (/webpack:/spec/testapp/app/assets/javascript/components/error-causing-component.js:2:9)
          JavaScript at /webpack:/spec/testapp/app/assets/javascript/components/error-causing-component.js:8:3
        MSG

        expect(error.message).to eql message.strip
      }
    end

    it "siliences render errors to the log" do
      ctx = MiniRacer::Context.new
      logger = Logger.new($stdout)
      Humid.config.raise_render_errors = false
      Humid.config.logger = logger
      Humid.prepare(ctx,
        application_path: build_path("reporting.js"),
        source_map_path: build_path("reporting.js.map")
      )

      expect(logger).to receive(:error)
      output = Humid.render(ctx)

      expect(output).to eql("")

      Humid.config.raise_render_errors = true
      Humid.config.logger = nil
    end
  end
end
