# frozen_string_literal: true

require 'aws-sdk-sqs'
require 'concurrent'

module ActiveJob
  module QueueAdapters
    # == Asynchronous adapter for Amazon SQS ActiveJob
    #
    # This adapter queues jobs asynchronously (ie non-blocking).
    # An error handler can be configured with:
    #   Aws::ActiveJob::SQS.config.async_queue_error_handler = ->(error, job, send_message_opts) { ... }
    #
    # To use this adapter, set up as:
    #   config.active_job.queue_adapter = :sqs_async
    class SqsAsyncAdapter < SqsAdapter
      private

      def _enqueue(job, body = nil, send_message_opts = {})
        # FIFO jobs must be queued in order, so do not queue async
        queue_url = Aws::ActiveJob::SQS.config.queue_url_for(job.queue_name)
        if Aws::ActiveJob::SQS.fifo?(queue_url)
          super
        else
          # Serialize is called here because the job’s locale needs to be
          # determined in this thread and not in some other thread.
          body = job.serialize # body is not a dead store
          Concurrent::Promises
            .future { super }
            .rescue do |e|
              Aws::ActiveJob::SQS.config.logger.error "Failed to queue job #{job}. Reason: #{e}"
              error_handler = Aws::ActiveJob::SQS.config.async_queue_error_handler
              error_handler&.call(e, job, send_message_opts)
            end
        end
      end
    end
  end
end
