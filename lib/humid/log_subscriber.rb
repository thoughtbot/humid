module Humid
  class LogSubscriber < ActiveSupport::LogSubscriber
    thread_cattr_accessor :humid_runtime

    def self.runtime=(value)
      self.humid_runtime = value
    end

    def self.runtime
      self.humid_runtime ||= 0
    end

    def self.reset_runtime
      rt, self.runtime = runtime, 0
      rt
    end

    def render(event)
      self.class.runtime += event.duration
    end
  end
end
