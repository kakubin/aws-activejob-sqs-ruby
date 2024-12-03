# frozen_string_literal: true

require 'optparse'

module Aws
  module ActiveJob
    module SQS
      # Utilities for the aws_active_job_sqs CLI.
      # @api private
      module CLI
        # rubocop:disable Metrics
        def self.parse_args(argv)
          out = { boot_rails: true }
          parser = ::OptionParser.new do |opts|
            opts.on('-q', '--queue STRING', '[Required] Queue to poll') { |a| out[:queue] = a }
            opts.on('-e', '--environment STRING',
                    'Rails environment (defaults to development). You can also use the APP_ENV or RAILS_ENV environment variables to specify the environment.') do |a|
              out[:environment] = a
            end
            opts.on('-t', '--threads INTEGER', Integer,
                    'The maximum number of worker threads to create.  Defaults to 2x the number of processors available on this system.') do |a|
              out[:threads] = a
            end
            opts.on('-b', '--backpressure INTEGER', Integer,
                    'The maximum number of messages to have waiting in the Executor queue. This should be a low, but non zero number.  Messages in the Executor queue cannot be picked up by other processes and will slow down shutdown.') do |a|
              out[:backpressure] = a
            end
            opts.on('-m', '--max_messages INTEGER', Integer,
                    'Max number of messages to receive in a batch from SQS.') do |a|
              out[:max_messages] = a
            end
            opts.on('-v', '--visibility_timeout INTEGER', Integer,
                    'The visibility timeout is the number of seconds that a message will not be processable by any other consumers. You should set this value to be longer than your expected job runtime to prevent other processes from picking up an running job.  See the SQS Visibility Timeout Documentation at https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-visibility-timeout.html.') do |a|
              out[:visibility_timeout] = a
            end
            opts.on('-s', '--shutdown_timeout INTEGER', Integer,
                    'The amount of time to wait for a clean shutdown.  Jobs that are unable to complete in this time will not be deleted from the SQS queue and will be retryable after the visibility timeout.') do |a|
              out[:shutdown_timeout] = a
            end
            opts.on('--[no-]rails [FLAG]', TrueClass,
                    'When set boots rails before running the poller.') do |a|
              out[:boot_rails] = a.nil? ? true : a
            end
            opts.on('-r', '--require STRING', String,
                    'Additional file to require before starting the poller.  Can be used to define/load job classes whith --no-rails.') do |a|
              out[:require] = a
            end
          end

          parser.banner = 'aws_active_job_sqs [options]'
          parser.on_tail '-h', '--help', 'Show help' do
            puts parser
            exit 1
          end

          parser.parse(argv)
          out
        end
        # rubocop:enable Metrics

        def self.boot_rails(options)
          environment = options[:environment] || ENV['APP_ENV'] || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
          ENV['RACK_ENV'] = ENV['RAILS_ENV'] = environment

          require 'rails'
          require File.expand_path('config/environment.rb')
        end
      end
    end
  end
end
