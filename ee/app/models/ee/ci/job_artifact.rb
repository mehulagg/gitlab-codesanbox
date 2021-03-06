# frozen_string_literal: true

module EE
  # CI::JobArtifact EE mixin
  #
  # This module is intended to encapsulate EE-specific model logic
  # and be prepended in the `Ci::JobArtifact` model
  module Ci::JobArtifact
    extend ActiveSupport::Concern

    prepended do
      after_destroy :log_geo_deleted_event

      SECURITY_REPORT_FILE_TYPES = %w[sast secret_detection dependency_scanning container_scanning dast coverage_fuzzing].freeze
      LICENSE_SCANNING_REPORT_FILE_TYPES = %w[license_management license_scanning].freeze
      DEPENDENCY_LIST_REPORT_FILE_TYPES = %w[dependency_scanning].freeze
      METRICS_REPORT_FILE_TYPES = %w[metrics].freeze
      CONTAINER_SCANNING_REPORT_TYPES = %w[container_scanning].freeze
      SAST_REPORT_TYPES = %w[sast].freeze
      SECRET_DETECTION_REPORT_TYPES = %w[secret_detection].freeze
      DAST_REPORT_TYPES = %w[dast].freeze
      REQUIREMENTS_REPORT_FILE_TYPES = %w[requirements].freeze
      COVERAGE_FUZZING_REPORT_TYPES = %w[coverage_fuzzing].freeze
      BROWSER_PERFORMANCE_REPORT_FILE_TYPES = %w[browser_performance performance].freeze

      scope :project_id_in, ->(ids) { where(project_id: ids) }
      scope :with_files_stored_remotely, -> { where(file_store: ::JobArtifactUploader::Store::REMOTE) }

      scope :security_reports, -> (file_types: SECURITY_REPORT_FILE_TYPES) do
        requested_file_types = *file_types

        with_file_types(requested_file_types & SECURITY_REPORT_FILE_TYPES)
      end

      scope :license_scanning_reports, -> do
        with_file_types(LICENSE_SCANNING_REPORT_FILE_TYPES)
      end

      scope :dependency_list_reports, -> do
        with_file_types(DEPENDENCY_LIST_REPORT_FILE_TYPES)
      end

      scope :container_scanning_reports, -> do
        with_file_types(CONTAINER_SCANNING_REPORT_TYPES)
      end

      scope :sast_reports, -> do
        with_file_types(SAST_REPORT_TYPES)
      end

      scope :secret_detection_reports, -> do
        with_file_types(SECRET_DETECTION_REPORT_TYPES)
      end

      scope :dast_reports, -> do
        with_file_types(DAST_REPORT_TYPES)
      end

      scope :metrics_reports, -> do
        with_file_types(METRICS_REPORT_FILE_TYPES)
      end

      scope :coverage_fuzzing_reports, -> do
        with_file_types(COVERAGE_FUZZING_REPORT_TYPES)
      end
    end

    class_methods do
      extend ::Gitlab::Utils::Override

      override :associated_file_types_for
      def associated_file_types_for(file_type)
        return LICENSE_SCANNING_REPORT_FILE_TYPES if LICENSE_SCANNING_REPORT_FILE_TYPES.include?(file_type)
        return BROWSER_PERFORMANCE_REPORT_FILE_TYPES if BROWSER_PERFORMANCE_REPORT_FILE_TYPES.include?(file_type)

        super
      end

      def replicables_for_geo_node(node = ::Gitlab::Geo.current_node)
        not_expired.merge(selective_sync_scope(node))
                   .merge(object_storage_scope(node))
      end

      def object_storage_scope(node)
        return all if node.sync_object_storage?

        with_files_stored_locally
      end

      def selective_sync_scope(node)
        return all unless node.selective_sync?

        project_id_in(node.projects)
      end
    end

    def log_geo_deleted_event
      ::Geo::JobArtifactDeletedEventStore.new(self).create!
    end
  end
end
