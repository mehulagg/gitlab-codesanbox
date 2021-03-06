# frozen_string_literal: true

module EE
  module API
    module API
      extend ActiveSupport::Concern

      prepended do
        use ::Gitlab::Middleware::IpRestrictor

        mount ::EE::API::Boards
        mount ::EE::API::GroupBoards

        mount ::API::AuditEvents
        mount ::API::ProjectApprovalRules
        mount ::API::ProjectApprovalSettings
        mount ::API::Unleash
        mount ::API::DependencyProxy
        mount ::API::EpicIssues
        mount ::API::EpicLinks
        mount ::API::Epics
        mount ::API::ElasticsearchIndexedNamespaces
        mount ::API::FeatureFlags
        mount ::API::FeatureFlagsUserLists
        mount ::API::FeatureFlagScopes
        mount ::API::Geo
        mount ::API::GeoReplication
        mount ::API::GeoNodes
        mount ::API::Ldap
        mount ::API::LdapGroupLinks
        mount ::API::License
        mount ::API::PersonalAccessTokens
        mount ::API::ProjectMirror
        mount ::API::ProjectPushRule
        mount ::API::GroupPushRule
        mount ::API::MergeTrains
        mount ::API::GroupHooks
        mount ::API::Scim
        mount ::API::ManagedLicenses
        mount ::API::ProjectApprovals
        mount ::API::Vulnerabilities
        mount ::API::VulnerabilityFindings
        mount ::API::VulnerabilityIssueLinks
        mount ::API::VulnerabilityExports
        mount ::API::MergeRequestApprovalRules
        mount ::API::ProjectAliases
        mount ::API::Dependencies
        mount ::API::VisualReviewDiscussions
        mount ::API::Analytics::CodeReviewAnalytics
        mount ::API::Analytics::GroupActivityAnalytics
        mount ::API::ProtectedEnvironments
        mount ::API::ResourceWeightEvents
        mount ::API::ResourceIterationEvents
      end
    end
  end
end
