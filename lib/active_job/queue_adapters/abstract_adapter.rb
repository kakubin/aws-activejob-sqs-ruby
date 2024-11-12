# frozen_string_literal: true

# This was added in Rails 7.2 When Rails 7.1 is dropped, this class can be removed.

module ActiveJob
  module QueueAdapters
    # = Active Job Abstract Adapter
    #
    # Active Job supports multiple job queue systems. ActiveJob::QueueAdapters::AbstractAdapter
    # forms the abstraction layer which makes this possible.
    class AbstractAdapter
      def enqueue(job)
        raise NotImplementedError
      end

      def enqueue_at(job, timestamp)
        raise NotImplementedError
      end
    end
  end
end
