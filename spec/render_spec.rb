require_relative "./support/helper"

RSpec.describe "Humid" do
  describe "create_context" do
    after(:each) do
      Humid.dispose
    end

    it "creates a context with initial js" do
      allow(Humid.config).to receive("application_path") { js_path "simple.js" }
      Humid.create_context

      expect(Humid.context).to be_kind_of(MiniRacer::Context)
    end

    context "When the file can not be found" do
      it "raises" do
        allow(Humid.config).to receive("application_path") { js_path "does_not_exist.js" }

        expect {
          Humid.create_context
        }.to raise_error(Errno::ENOENT)
      end
    end

    it "does not have timeouts, immediates, and intervals" do
      allow(Humid.config).to receive("application_path") { js_path "simple.js" }

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
      allow(Humid.config).to receive("application_path") { js_path "simple.js" }
      Humid.create_context
      expect(Humid.logger).to receive(:info).with("hello")

      Humid.context.eval("console.info('hello')")
    end
  end

  describe "context" do
    it "returns the created context" do
      allow(Humid.config).to receive("application_path") { js_path "simple.js" }

      Humid.create_context

      expect(Humid.context).to be_kind_of(MiniRacer::Context)
    end
  end

  describe "render" do
    it "returns a js output" do
      allow(Humid.config).to receive("application_path") { js_path "simple.js" }
      Humid.create_context

      expect(Humid.render).to eql("hello")
    end

    it "applys args to the func" do
      allow(Humid.config).to receive("application_path") { js_path "args.js" }
      Humid.create_context

      args = ["a", 1, 2, [], {}]

      expect(Humid.render(*args)).to eql({"0" => "a", "1" => 1, "2" => 2, "3" => [], "4" => {}})
    end

    it "can use source maps to see errors" do
      system("yarn run build")
      allow(Humid.config).to receive("application_path") { build_path "reporting.js" }
      allow(Humid.config).to receive("source_map_path") { build_path "reporting.js.map" }

      Humid.create_context

      expect {
        Humid.render
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
      allow(Humid.config).to receive("application_path") { build_path "reporting.js" }
      allow(Humid.config).to receive("source_map_path") { build_path "reporting.js.map" }
      allow(Humid.config).to receive("raise_render_errors") { false }

      Humid.create_context

      expect(Humid.logger).to receive(:error)
      output = Humid.render

      expect(output).to eql("")
    end
  end
end
