module Humid
  module ControllerRuntime
    extend ActiveSupport::Concern

    module ClassMethods
      def log_process_action(payload)
        messages, humid_runtime = super, payload[:humid_runtime]
        messages << ("Humid SSR: %.1fms" % humid_runtime.to_f) if humid_runtime
        messages
      end
    end

    private

    attr_internal :humid_runtime

    # Reset the runtime before each action.
    def process_action(action, *args)
      Humid::LogSubscriber.reset_runtime
      super
    end

    def cleanup_view_runtime
      if logger&.info?
        humid_rt_before_render = Humid::LogSubscriber.reset_runtime
        self.humid_runtime = (humid_runtime || 0) + humid_rt_before_render
        runtime = super
        humid_rt_after_render = Humid::LogSubscriber.reset_runtime
        self.humid_runtime += humid_rt_after_render
        runtime - humid_rt_after_render
      else
        super
      end
    end

    def append_info_to_payload(payload)
      super
      payload[:humid_runtime] = (humid_runtime || 0) + Humid::LogSubscriber.reset_runtime
    end
  end
end
