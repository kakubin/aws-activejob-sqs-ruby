# frozen_string_literal: true

module Aws
  module ActiveJob
    # Configuration for AWS ActiveJob SQS.
    module SQS
      # Use +Aws::ActiveJob::SQS.config+ to access the singleton config instance.
      class Configuration
        # Default configuration options
        # @api private
        DEFAULTS = {
          max_messages: 10,
          shutdown_timeout: 15,
          retry_standard_errors: true, # TODO: Remove in next MV
          queues: {},
          logger: ActiveSupport::Logger.new($stdout), # ::Rails.logger,
          message_group_id: 'SqsActiveJobGroup',
          excluded_deduplication_keys: ['job_id']
        }.freeze

        # @api private
        attr_accessor :queues, :max_messages, :visibility_timeout,
                      :shutdown_timeout, :client, :logger,
                      :async_queue_error_handler, :message_group_id

        attr_reader :excluded_deduplication_keys

        # Don't use this method directly: Configuration is a singleton class, use
        # +Aws::ActiveJob::SQS.config+ to access the singleton config.
        #
        # @param [Hash] options
        # @option options [Hash[Symbol, String]] :queues A mapping between the
        #   active job queue name and the SQS Queue URL. Note: multiple active
        #   job queues can map to the same SQS Queue URL.
        #
        # @option options  [Integer] :max_messages
        #    The max number of messages to poll for in a batch.
        #
        # @option options [Integer] :visibility_timeout
        #   If unset, the visibility timeout configured on the
        #   SQS queue will be used.
        #   The visibility timeout is the number of seconds
        #   that a message will not be processable by any other consumers.
        #   You should set this value to be longer than your expected job runtime
        #   to prevent other processes from picking up an running job.
        #   See the (SQS Visibility Timeout Documentation)[https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-visibility-timeout.html]
        #
        # @option options [Integer] :shutdown_timeout
        #   the amount of time to wait
        #   for a clean shutdown.  Jobs that are unable to complete in this time
        #   will not be deleted from the SQS queue and will be retryable after
        #   the visibility timeout.
        #
        # @ option options [Boolean] :retry_standard_errors
        #   If `true`, StandardErrors raised by ActiveJobs are left on the queue
        #   and will be retried (pending the SQS Queue's redrive/DLQ/maximum receive settings).
        #   This behavior overrides the standard Rails ActiveJob
        #   [Retry/Discard for failed jobs](https://guides.rubyonrails.org/active_job_basics.html#retrying-or-discarding-failed-jobs)
        #   behavior.  When set to `true` the retries provided by this will be
        #   on top of any retries configured on the job with `retry_on`.
        #   When `false`, retry behavior is fully configured
        #   through `retry_on`/`discard_on` on the ActiveJobs.
        #
        # @option options [ActiveSupport::Logger] :logger Logger to use
        #   for the poller.
        #
        # @option options [String] :config_file
        #   Override file to load configuration from. If not specified will
        #   attempt to load from config/aws_sqs_active_job.yml.
        #
        # @option options [String] :message_group_id (SqsActiveJobGroup)
        #  The message_group_id to use for queueing messages on a fifo queues.
        #  Applies only to jobs queued on FIFO queues.
        #  See the (SQS FIFO Documentation)[https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/FIFO-queues.html]
        #
        # @option options [Callable] :async_queue_error_handler An error handler
        #   to be called when the async active job adapter experiences an error
        #   queueing a job.  Only applies when
        #   +active_job.queue_adapter = :sqs_async+.  Called with:
        #   [error, job, job_options]
        #
        # @option options [SQS::Client] :client SQS Client to use. A default
        #   client will be created if none is provided.
        #
        # @option options [Array] :excluded_deduplication_keys (['job_id'])
        #   The type of keys stored in the array should be String or Symbol.
        #   Using this option, job_id is implicitly added to the keys.

        def initialize(options = {})
          options[:config_file] ||= config_file
          options = DEFAULTS
                    .merge(file_options(options))
                    .merge(options)
          set_attributes(options)
        end

        def excluded_deduplication_keys=(keys)
          @excluded_deduplication_keys = keys.map(&:to_s) | ['job_id']
        end

        def client
          @client ||= begin
            client = Aws::SQS::Client.new
            client.config.user_agent_frameworks << 'aws-activejob-sqs'
            client
          end
        end

        # Return the queue_url for a given job_queue name
        def queue_url_for(job_queue)
          job_queue = job_queue.to_sym
          raise ArgumentError, "No queue defined for #{job_queue}" unless queues.key? job_queue

          queues[job_queue]
        end

        # @api private
        def to_s
          to_h.to_s
        end

        # @api private
        def to_h
          h = {}
          instance_variables.each do |v|
            v_sym = v.to_s.delete('@').to_sym
            val = instance_variable_get(v)
            h[v_sym] = val
          end
          h
        end

        private

        # Set accessible attributes after merged options.
        def set_attributes(options)
          options.each_key do |opt_name|
            instance_variable_set("@#{opt_name}", options[opt_name])
            client.config.user_agent_frameworks << 'aws-sdk-rails' if opt_name == :client
          end
        end

        def file_options(options = {})
          if options[:config_file]
            load_from_file(options[:config_file])
          else
            {}
          end
        end

        def config_file
          return unless defined?(::Rails)
          file = ENV.fetch('AWS_SQS_ACTIVE_JOB_CONFIG_FILE', nil)
          file = ::Rails.root.join("config/aws_sqs_active_job/#{::Rails.env}.yml") unless file
          file = ::Rails.root.join('config/aws_sqs_active_job.yml') unless File.exist?(file)
          file
        end

        # Load options from YAML file
        def load_from_file(file_path)
          opts = load_yaml(file_path) || {}
          opts.deep_symbolize_keys
        end

        def load_yaml(file_path)
          require 'erb'
          source = ERB.new(File.read(file_path)).result

          # Avoid incompatible changes with Psych 4.0.0
          # https://bugs.ruby-lang.org/issues/17866
          begin
            YAML.safe_load(source, aliases: true) || {}
          rescue ArgumentError
            YAML.safe_load(source) || {}
          end
        end
      end
    end
  end
end
