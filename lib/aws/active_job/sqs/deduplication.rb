# frozen_string_literal: true

module Aws
  module ActiveJob
    module SQS
      extend ActiveSupport::Concern

      included do
        class_attribute :excluded_deduplication_keys
      end

      # class methods for SQS ActiveJob.
      module ClassMethods
        def deduplicate_without(*keys)
          self.excluded_deduplication_keys = keys.map(&:to_s) | ['job_id']
        end
      end
    end
  end
end
