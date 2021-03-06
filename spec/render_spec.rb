require_relative "./support/helper"

RSpec.describe "Humid" do
  around(:each) do |example|
    app_path = File.expand_path("./testapp", File.dirname(__FILE__))
    Dir.chdir(app_path) do
      example.run
    end
  end

  describe "create_context" do
    after(:each) do
      Humid.dispose
    end

    it "creates a context with initial js" do
      allow(Humid.config).to receive("server_rendering_pack") { "simple.js" }
      Humid.create_context

      expect(Humid.context).to be_kind_of(MiniRacer::Context)
    end

    context "When the file can not be found" do
      it "raises" do
        allow(Humid.config).to receive("server_rendering_pack") { "does_not_exist.js" }

        expect {
          Humid.create_context
        }.to raise_error(Humid::FileNotFound, "Humid could not find a built pack for does_not_exist.js")
      end
    end

    it "does not have timeouts, immediates, and intervals" do
      allow(Humid.config).to receive("server_rendering_pack") { "simple.js" }

      Humid.create_context

      expect {
        Humid.context.eval("setTimeout()")
      }.to raise_error(MiniRacer::RuntimeError, "ReferenceError: setTimeout is not defined")
      expect {
        Humid.context.eval("setInterval()")
      }.to raise_error(MiniRacer::RuntimeError, "ReferenceError: setInterval is not defined")
      expect {
        Humid.context.eval("clearTimeout()")
      }.to raise_error(MiniRacer::RuntimeError, "ReferenceError: clearTimeout is not defined")
      expect {
        Humid.context.eval("setImmediate()")
      }.to raise_error(MiniRacer::RuntimeError, "ReferenceError: setImmediate is not defined")
      expect {
        Humid.context.eval("clearImmediate()")
      }.to raise_error(MiniRacer::RuntimeError, "ReferenceError: clearImmediate is not defined")
    end

    it "proxies to Rails logger" do
      allow(Humid.config).to receive("server_rendering_pack") { "simple.js" }
      Humid.create_context
      expect(Humid.logger).to receive(:info).with("hello")

      Humid.context.eval("console.info('hello')")
    end
  end

  describe "context" do
    it "returns the created context" do
      allow(Humid.config).to receive("server_rendering_pack") { "simple.js" }

      Humid.create_context

      expect(Humid.context).to be_kind_of(MiniRacer::Context)
    end

    context "when the js is stale and env is NOT dev`" do
      it "does not recompile the JS" do
        allow(Webpacker).to receive_message_chain("env.development?") { false }
        allow(Webpacker).to receive_message_chain("compiler.stale?") { true }
        allow(Humid.config).to receive("server_rendering_pack") { "simple.js" }

        Humid.create_context
        prev_context = Humid.context
        expect(prev_context).to be_kind_of(MiniRacer::Context)

        allow(Webpacker).to receive_message_chain("compiler.stale?") { true }

        next_context = Humid.context

        expect(prev_context).to eql(next_context)
        expect(next_context).to be_kind_of(MiniRacer::Context)
      end
    end

    context "when the env is development" do
      it "compiles the JS when stale" do
        allow(Webpacker).to receive_message_chain("env.development?") { true }
        allow(Webpacker).to receive_message_chain("compiler.stale?") { true }
        allow(Webpacker).to receive_message_chain("compiler.compile")
        allow(Humid.config).to receive("server_rendering_pack") { "simple.js" }

        Humid.create_context
        prev_context = Humid.context
        expect(prev_context).to be_kind_of(MiniRacer::Context)

        allow(Webpacker).to receive_message_chain("compiler.stale?") { true }
        # This simulates a changing file
        allow(Humid.config).to receive("server_rendering_pack") { "simple_changed.js" }

        next_context = Humid.context

        expect(prev_context).to_not eql(next_context)
        expect(next_context).to be_kind_of(MiniRacer::Context)
      end

      it "creates a new context when webpack-devserver already handled JS staleness" do
        allow(Webpacker).to receive_message_chain("env.development?") { true }
        allow(Webpacker).to receive_message_chain("compiler.stale?") { true }
        allow(Webpacker).to receive_message_chain("compiler.compile")
        allow(Humid.config).to receive("server_rendering_pack") { "simple.js" }

        Humid.create_context
        prev_context = Humid.context
        expect(Humid.render).to eql("hello")
        expect(prev_context).to be_kind_of(MiniRacer::Context)

        allow(Webpacker).to receive_message_chain("compiler.stale?") { false }
        # This simulates a changing file
        allow(Humid.config).to receive("server_rendering_pack") { "simple_changed.js" }

        next_context = Humid.context

        expect(prev_context).to_not eql(next_context)
        expect(next_context).to be_kind_of(MiniRacer::Context)
        expect(Humid.render).to eql("hello changed")
      end
    end
  end

  describe "render" do
    it "returns a js output" do
      allow(Humid.config).to receive("server_rendering_pack") { "simple.js" }
      Humid.create_context

      expect(Humid.render).to eql("hello")
    end

    it "applys args to the func" do
      allow(Humid.config).to receive("server_rendering_pack") { "args.js" }
      Humid.create_context

      args = ["a", 1, 2, [], {}]

      expect(Humid.render(*args)).to eql({"0" => "a", "1" => 1, "2" => 2, "3" => [], "4" => {}})
    end

    it "can use source maps to see errors" do
      allow(Humid.config).to receive("server_rendering_pack") { "reporting.js" }
      allow(Humid.config).to receive("use_source_map") { true }

      Humid.create_context

      expect {
        Humid.render
      }.to raise_error { |error|
        expect(error).to be_a(Humid::RenderError)
        message = <<~MSG
          Error: ^^ Look! These stack traces map to the actual source code :)
          JavaScript at throwSomeError (/webpack:/app/javascript/packs/components/error-causing-component.js:2:1)
          JavaScript at ErrorCausingComponent (/webpack:/app/javascript/packs/components/error-causing-component.js:8:1)
          JavaScript at /webpack:/app/javascript/packs/reporting.js:18:1
        MSG

        expect(error.message).to eql message.strip
      }
    end

    it "siliences render errors to the log" do
      allow(Humid.config).to receive("server_rendering_pack") { "reporting.js" }
      allow(Humid.config).to receive("raise_render_errors") { false }
      allow(Humid.config).to receive("use_source_map") { true }

      Humid.create_context

      expect(Humid.logger).to receive(:error)
      output = Humid.render

      expect(output).to eql("")
    end
  end
end
