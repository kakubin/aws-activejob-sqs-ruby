# frozen_string_literal: true

require 'aws-sdk-sqs'
require 'concurrent'

module Aws
  module ActiveJob
    module SQS
      # CLI runner for polling for SQS ActiveJobs
      # Use `aws_active_job_sqs --help` for detailed usage
      class Poller
        class Interrupt < StandardError; end

        def initialize(options = {})
          @options = options
        end

        def run
          Aws::ActiveJob::SQS.configure do |cfg|
            @options.each_pair do |key, value|
              cfg.send(:"#{key}=", value) if cfg.respond_to?(:"#{key}=")
            end
          end

          validate_config

          config = Aws::ActiveJob::SQS.config

          # ensure we have a logger configured
          @logger = config.logger || ActiveSupport::Logger.new($stdout)
          @logger.info("Starting Poller with config=#{config.to_h}")

          Signal.trap('INT') { raise Interrupt }
          Signal.trap('TERM') { raise Interrupt }
          @executor = Executor.new(
            max_threads: config.threads,
            logger: @logger,
            max_queue: config.backpressure,
            error_handler: config.poller_error_handler
          )

          poll
        rescue Interrupt
          @logger.info 'Process Interrupted or killed - attempting to shutdown cleanly.'
          shutdown(config.shutdown_timeout)
          exit
        end

        private

        def shutdown(timeout)
          @executor.shutdown(timeout)
        end

        def poll
          config = Configuration.new(@options)
          queue = @options[:queue]
          queue_url = config.url_for(queue)
          @poller = Aws::SQS::QueuePoller.new(queue_url, client: config.client)
          poller_options = {
            skip_delete: true,
            max_number_of_messages: config.max_messages_for(queue),
            visibility_timeout: config.visibility_timeout_for(queue)
          }
          # Limit max_number_of_messages for FIFO queues to 1
          # this ensures jobs with the same message_group_id are processed
          # in order
          # Jobs with different message_group_id will be processed in
          # parallel and may be out of order.
          poller_options[:max_number_of_messages] = 1 if Aws::ActiveJob::SQS.fifo?(queue_url)

          single_message = poller_options[:max_number_of_messages] == 1

          @logger.info "Polling on: #{queue} => #{queue_url} with options=#{poller_options}"

          _poll(config.client, poller_options, queue_url, single_message)
        end

        def _poll(client, poller_options, queue_url, single_message)
          @poller.poll(poller_options) do |msgs|
            msgs = [msgs] if single_message
            @logger.info "Processing batch of #{msgs.length} messages"
            msgs.each do |msg|
              @executor.execute(Aws::SQS::Message.new(
                                  queue_url: queue_url,
                                  receipt_handle: msg.receipt_handle,
                                  data: msg,
                                  client: client
                                ))
            end
          end
        end

        def validate_config
          raise ArgumentError, 'You must specify the name of the queue to process jobs from' unless @options[:queue]
        end
      end
    end
  end
end
