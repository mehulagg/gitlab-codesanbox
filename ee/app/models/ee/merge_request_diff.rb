# frozen_string_literal: true

module EE
  module MergeRequestDiff
    extend ActiveSupport::Concern

    prepended do
      include ::Gitlab::Geo::ReplicableModel
      include ObjectStorable

      STORE_COLUMN = :external_diff_store

      with_replicator Geo::MergeRequestDiffReplicator

      has_one :merge_request_diff_detail, inverse_of: :merge_request_diff

      delegate :verification_retry_at, :verification_retry_at=,
               :verified_at, :verified_at=,
               :verification_checksum, :verification_checksum=,
               :verification_failure, :verification_failure=,
               :verification_retry_count, :verification_retry_count=,
        to: :merge_request_diff_detail, allow_nil: true

      scope :has_external_diffs, -> { with_files.where(stored_externally: true) }
      scope :project_id_in, ->(ids) { where(merge_request_id: ::MergeRequest.where(target_project_id: ids)) }

      scope :checksummed, -> { has_external_diffs.where(merge_request_diff_detail: ::MergeRequestDiffDetail.checksummed) }
      scope :checksum_failed, -> { has_external_diffs.where(merge_request_diff_detail: ::MergeRequestDiffDetail.checksum_failed) }
    end

    class_methods do
      def replicables_for_geo_node(node = ::Gitlab::Geo.current_node)
        has_external_diffs.merge(selective_sync_scope(node))
                          .merge(object_storage_scope(node))
      end

      private

      def object_storage_scope(node)
        return all if node.sync_object_storage?

        with_files_stored_locally
      end

      def selective_sync_scope(node)
        return all unless node.selective_sync?

        project_id_in(node.projects)
      end
    end

    def merge_request_diff_detail
      super || build_merge_request_diff_detail
    end

    def local?
      stored_externally? && external_diff_store == ExternalDiffUploader::Store::LOCAL
    end

    def log_geo_deleted_event
      # Keep empty for now. Should be addressed in future
      # by https://gitlab.com/gitlab-org/gitlab/issues/33817
    end
  end
end
