# frozen_string_literal: true

require 'aws/active_job/sqs/poller'

module Aws
  module ActiveJob
    module SQS
      describe Poller do
        let(:queue_poller) { double(Aws::SQS::QueuePoller) }
        let(:msg) { double('SQSMessage', receipt_handle: '1234') }
        let(:logger) { double(info: nil) }
        let(:sqs_client) { Aws::SQS::Client.new(stub_responses: true) }

        before do
          allow(ActiveSupport::Logger).to receive(:new).and_return(logger)
          Aws::ActiveJob::SQS.config.client = sqs_client
        end

        describe '#initialize' do
          it 'parses args' do
            poller = Poller.new(['--queue', 'default', '-v', '360'])
            parsed = poller.instance_variable_get(:@options)
            expect(parsed[:queue]).to eq 'default'
            expect(parsed[:visibility_timeout]).to eq 360
          end
        end

        describe '#run' do
          let(:poller) { Poller.new(['--queue', 'default', '-v', '360']) }

          it 'boots rails' do
            expect(poller).to receive(:require).with('rails')
            expect(poller).to receive(:require).with(
              File.expand_path('config/environment.rb')
            )

            allow(poller).to receive(:poll) # no-op the poll
            poller.run

            expect(ENV.fetch('RACK_ENV', nil)).to eq 'test'
            expect(ENV.fetch('RAILS_ENV', nil)).to eq 'test'
          end

          it 'merges args with loaded config' do
            allow(poller).to receive(:boot_rails) # no-op the boot

            allow(poller).to receive(:poll) # no-op the poll
            poller.run

            options = poller.instance_variable_get(:@options)
            expect(options[:max_messages]).to eq 5 # from test app config file
            expect(options[:visibility_timeout]).to eq 360 # from argv
            expect(options[:shutdown_timeout]).to eq 15 # from defaults
          end

          it 'polls the configured queue' do
            allow(poller).to receive(:boot_rails) # no-op the boot
            expect(Aws::SQS::QueuePoller).to receive(:new).with(
              'https://queue-url',
              { client: instance_of(Aws::SQS::Client) }
            ).and_return(queue_poller)

            expect(queue_poller).to receive(:poll)
            poller.run
          end

          it 'runs the poller with the configured options' do
            allow(poller).to receive(:boot_rails) # no-op the boot
            expect(Aws::SQS::QueuePoller).to receive(:new).and_return(queue_poller)

            expect(queue_poller).to receive(:poll).with(
              {
                skip_delete: true,
                max_number_of_messages: 5,
                visibility_timeout: 360
              }
            )

            poller.run
          end

          it 'sets max_number_of_messages to 1 for fifo queues' do
            allow(poller).to receive(:boot_rails) # no-op the boot

            allow(Aws::ActiveJob::SQS.config).to receive(:queue_url_for).and_return('https://queue-url.fifo')
            expect(Aws::SQS::QueuePoller).to receive(:new).and_return(queue_poller)

            expect(queue_poller).to receive(:poll).with(
              {
                skip_delete: true,
                max_number_of_messages: 1,
                visibility_timeout: 360
              }
            )

            poller.run
          end

          it 'polls for messages and executes them' do
            allow(poller).to receive(:boot_rails) # no-op the boot

            executor = double(Executor)
            expect(Executor).to receive(:new).and_return(executor)

            expect(Aws::SQS::QueuePoller).to receive(:new).and_return(queue_poller)
            expect(queue_poller).to receive(:poll) { |&block| block.call([msg, msg]) }

            expect(executor).to receive(:execute).twice.with(instance_of(Aws::SQS::Message))

            poller.run
          end

          it 'calls shutdown when interrupted' do
            allow(poller).to receive(:boot_rails) # no-op the boot

            executor = double(Executor)
            expect(Executor).to receive(:new).and_return(executor)

            expect(Aws::SQS::QueuePoller).to receive(:new).and_return(queue_poller)
            expect(queue_poller).to receive(:poll).and_raise(Poller::Interrupt)

            expect(executor).to receive(:shutdown)
            expect(poller).to receive(:exit) # no-op the exit

            poller.run
          end
        end
      end
    end
  end
end
