# frozen_string_literal: true

module Geo
  module BlobReplicatorStrategy
    extend ActiveSupport::Concern

    include Delay
    include Gitlab::Geo::LogHelpers

    included do
      event :created
      event :deleted
    end

    def handle_after_create_commit
      return unless self.class.enabled?

      publish(:created, **created_params)
      schedule_checksum_calculation if needs_checksum?
    end

    # Called by Gitlab::Geo::Replicator#consume
    def consume_event_created(**params)
      return unless in_replicables_for_geo_node?

      download
    end

    # Called by Gitlab::Geo::Replicator#consume
    def consume_event_deleted(**params)
      replicate_destroy(params)
    end

    # Return the carrierwave uploader instance scoped to current model
    #
    # @abstract
    # @return [Carrierwave::Uploader]
    def carrierwave_uploader
      raise NotImplementedError
    end

    # Return the absolute path to locally stored package file
    #
    # @return [String] File path
    def blob_path
      carrierwave_uploader.path
    end

    def calculate_checksum!
      checksum = model_record.calculate_checksum!
      update_verification_state!(checksum: checksum)
    rescue => e
      log_error('Error calculating the checksum', e)
      update_verification_state!(failure: e.message)
    end

    # Check if given checksum matches known one
    #
    # @param [String] checksum
    # @return [Boolean] whether checksum matches
    def matches_checksum?(checksum)
      model_record.verification_checksum == checksum
    end

    private

    # Update checksum on Geo primary database
    #
    # @param [String] checksum value generated by the checksum routine
    # @param [String] failure (optional) stacktrace from failed execution
    def update_verification_state!(checksum: nil, failure: nil)
      retry_at, retry_count = calculate_next_retry_attempt if failure.present?

      model_record.update!(
        verification_checksum: checksum,
        verified_at: Time.current,
        verification_failure: failure,
        verification_retry_at: retry_at,
        verification_retry_count: retry_count
      )
    end

    def calculate_next_retry_attempt
      retry_count = model_record.verification_retry_count.to_i + 1
      [next_retry_time(retry_count), retry_count]
    end

    def download
      ::Geo::BlobDownloadService.new(replicator: self).execute
    end

    def replicate_destroy(event_data)
      ::Geo::FileRegistryRemovalService.new(
        replicable_name,
        model_record_id,
        event_data[:blob_path]
      ).execute
    end

    def deleted_params
      { model_record_id: model_record.id, blob_path: blob_path }
    end

    def schedule_checksum_calculation
      Geo::BlobVerificationPrimaryWorker.perform_async(replicable_name, model_record.id)
    end
  end
end
