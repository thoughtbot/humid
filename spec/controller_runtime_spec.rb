require_relative "./support/helper"

describe Humid::ControllerRuntime do
  controller_runtime = Humid::ControllerRuntime

  def set_metric value
    Humid::LogSubscriber.runtime = value
  end

  def clear_metric!
    Humid::LogSubscriber.reset_runtime = 0
  end

  reference_controller_class = Class.new {
    def process_action *_
      @process_action = true
    end

    def cleanup_view_runtime *_
      @cleanup_view_runtime.call
    end

    def append_info_to_payload *_
      @append_info_to_payload = true
    end

    def self.log_process_action *_
      @log_process_action.call
    end
  }

  controller_class = Class.new reference_controller_class do
    include controller_runtime

    def logger
      Logger.new(STDOUT)
    end
  end

  let(:controller) { controller_class.new }

  it "resets the metric before each action" do
    set_metric 42
    controller.send(:process_action, "foo")
    expect(Humid::LogSubscriber.runtime).to be(0)
    expect(controller.instance_variable_get("@process_action")).to be(true)
  end

  it "strips the metric of other sources of the runtime" do
    set_metric 1
    controller.instance_variable_set "@cleanup_view_runtime", -> {
      controller.instance_variable_set "@cleanup_view_runtime", true
      set_metric 13
      42
    }
    returned = controller.send :cleanup_view_runtime
    expect(controller.instance_variable_get("@cleanup_view_runtime")).to be(true)
    expect(controller.humid_runtime).to eq(14)
    expect(returned).to be(29)
  end

  it "appends the metric to payload" do
    payload = {}
    set_metric 42
    controller.send :append_info_to_payload, payload
    expect(controller.instance_variable_get("@append_info_to_payload")).to be(true)
    expect(payload[:humid_runtime]).to eq(42)
  end

  it "adds metric to log message" do
    controller_class.instance_variable_set "@log_process_action", -> {
      controller_class.instance_variable_set "@log_process_action", true
      []
    }
    messages = controller_class.log_process_action humid_runtime: 42.101
    expect(controller_class.instance_variable_get("@log_process_action")).to be(true)
    expect(messages).to eq(["Humid SSR: 42.1ms"])
  end
end
