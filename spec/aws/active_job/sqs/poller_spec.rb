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
          allow(Aws::ActiveJob::SQS.config).to receive(:client).and_return(sqs_client)
        end

        describe '#initialize' do
          it 'initializes options' do
            poller = Poller.new(max_messages: 3, visibility_timeout: 360)
            parsed = poller.instance_variable_get(:@options)
            expect(parsed[:max_messages]).to eq 3
            expect(parsed[:visibility_timeout]).to eq 360
          end
        end

        describe '#run' do
          let(:poller) do
            Poller.new(
              queue: :default,
              visibility_timeout: 360,
              shutdown_timeout: 42
            )
          end

          it 'merges args with loaded config' do
            expect(Aws::SQS::QueuePoller).to receive(:new).and_return(queue_poller)

            expect(queue_poller).to receive(:poll).with(
              {
                skip_delete: true,
                max_number_of_messages: 2, # from test app config file
                visibility_timeout: 360 # from options
              }
            )

            poller.run
          end

          it 'polls the configured queue' do
            expect(Aws::SQS::QueuePoller).to receive(:new).with(
              'https://queue-url',
              { client: instance_of(Aws::SQS::Client) }
            ).and_return(queue_poller)

            expect(queue_poller).to receive(:poll)
            poller.run
          end

          it 'runs the poller with the configured options' do
            expect(Aws::SQS::QueuePoller).to receive(:new).and_return(queue_poller)

            expect(queue_poller).to receive(:poll).with(
              {
                skip_delete: true,
                max_number_of_messages: 2, # from queue config in app config file
                visibility_timeout: 360
              }
            )

            poller.run
          end

          it 'sets max_number_of_messages to 1 for fifo queues' do
            allow_any_instance_of(Configuration).to receive(:url_for).and_return('https://queue-url.fifo')
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
            executor = double(Executor)
            expect(Executor).to receive(:new).and_return(executor)

            expect(Aws::SQS::QueuePoller).to receive(:new).and_return(queue_poller)
            expect(queue_poller).to receive(:poll) { |&block| block.call([msg, msg]) }

            expect(executor).to receive(:execute).twice.with(instance_of(Aws::SQS::Message))

            poller.run
          end

          it 'calls shutdown when interrupted' do
            executor = double(Executor)
            expect(Executor).to receive(:new).and_return(executor)

            expect(Aws::SQS::QueuePoller).to receive(:new).and_return(queue_poller)
            expect(queue_poller).to receive(:poll).and_raise(Poller::Interrupt)

            expect(executor).to receive(:shutdown).with(42) # from options
            expect(poller).to receive(:exit) # no-op the exit

            poller.run
          end
        end
      end
    end
  end
end
