# frozen_string_literal: true

module EE
  module Types
    module MilestoneType
      extend ActiveSupport::Concern

      prepended do
        implements ::Types::TimeboxBurnupTimeSeriesInterface
      end
    end
  end
end
