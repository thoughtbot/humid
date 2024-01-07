require_relative "./support/helper"
require "active_support/log_subscriber/test_helper"

RSpec.describe Humid::LogSubscriber do
  around(:each) do |example|
    app_path = File.expand_path("./testapp", File.dirname(__FILE__))
    Dir.chdir(app_path) do
      example.run
    end
  end

  before(:each) do
    Humid::LogSubscriber.reset_runtime
  end

  def current
    Thread.current.active_support_execution_state
  end

  def key
    if Rails.version >= "7.1"
      "attr_humid_runtime_#{Humid::LogSubscriber.object_id}"
    else
      "attr_Humid::LogSubscriber_humid_runtime"
    end
  end

  context ".runtime" do
    it "is returns the runtime from the thread local" do
      expect(Humid::LogSubscriber.runtime).to eql 0
      current[key] = 3
      expect(Humid::LogSubscriber.runtime).to eql 3
    end
  end

  context ".runtime=" do
    it "sets the runtime in a thread-safe manner" do
      expect(Humid::LogSubscriber.runtime).to eql 0
      Humid::LogSubscriber.runtime = 3
      expect(current[key]).to eql 3
    end
  end

  context ".reset_runtime" do
    it "resets the runtime" do
      Humid::LogSubscriber.runtime = 3
      expect(current[key]).to eql 3

      Humid::LogSubscriber.reset_runtime
      expect(current[key]).to eql 0
      expect(Humid::LogSubscriber.runtime).to eql 0
    end
  end

  it "is attached" do
    allow(Humid.config).to receive("application_path") {
      js_path "simple.js"
    }
    Humid.create_context
    expect(Humid::LogSubscriber.runtime).to eql(0)
    Humid.render
    expect(Humid::LogSubscriber.runtime).to be > 0
  end
end
