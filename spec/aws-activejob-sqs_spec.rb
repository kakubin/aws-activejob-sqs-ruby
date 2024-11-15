# frozen_string_literal: true

module Aws
  module ActiveJob
    describe SQS do
      describe '.config' do
        before { Aws::ActiveJob::SQS.instance_variable_set(:@config, nil) }

        it 'creates and returns configuration' do
          expect(Aws::ActiveJob::SQS::Configuration).to receive(:new).and_call_original
          expect(Aws::ActiveJob::SQS.config).to be_a Aws::ActiveJob::SQS::Configuration
        end

        it 'creates config only once' do
          expect(Aws::ActiveJob::SQS::Configuration).to receive(:new).once.and_call_original
          # call twice
          Aws::ActiveJob::SQS.config
          Aws::ActiveJob::SQS.config
        end
      end

      describe '.configure' do
        it 'allows configuration through a block' do
          Aws::ActiveJob::SQS.configure do |config|
            config.visibility_timeout = 360
            config.excluded_deduplication_keys = [:job_class]
          end

          expect(Aws::ActiveJob::SQS.config).to have_attributes(
            visibility_timeout: 360,
            excluded_deduplication_keys: contain_exactly('job_class', 'job_id')
          )
        end
      end

      describe '.fifo?' do
        it 'returns true if queue_url is fifo' do
          queue_url = 'https://sqs.us-west-2.amazonaws.com/012345678910/queue.fifo'
          expect(Aws::ActiveJob::SQS.fifo?(queue_url)).to be(true)
        end

        it 'returns false if queue_url is not fifo' do
          queue_url = 'https://sqs.us-west-2.amazonaws.com/012345678910/queue'
          expect(Aws::ActiveJob::SQS.fifo?(queue_url)).to be(false)
        end
      end
    end
  end
end
