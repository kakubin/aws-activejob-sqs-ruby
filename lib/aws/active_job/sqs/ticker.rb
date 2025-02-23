# frozen_string_literal: true

require 'concurrent'

module Aws
  module ActiveJob
    module SQS
      # Extend message visibility_timeout
      class Ticker
        EXTEND_UPFRONT_SECONDS = 5

        def initialize(message)
          @timer_task = new_timer_task(message).tap(&:execute)
        end

        def finish
          @timer_task&.kill
        end

        private

        def new_timer_task(message)
          queue_visibility_timeout = 30
          execution_interval = queue_visibility_timeout - EXTEND_UPFRONT_SECONDS

          Concurrent::TimerTask.new(execution_interval: execution_interval) do
            message.change_visibility(visibility_timeout: queue_visibility_timeout)
          end
        end
      end
    end
  end
end
