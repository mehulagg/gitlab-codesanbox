# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::UsageData, :aggregate_failures do
  include UsageDataHelpers

  before do
    stub_usage_data_connections
    stub_object_store_settings
  end

  describe '.uncached_data' do
    describe '.usage_activity_by_stage' do
      subject { described_class.uncached_data }

      it 'includes usage_activity_by_stage data' do
        is_expected.to include(:usage_activity_by_stage)
        is_expected.to include(:usage_activity_by_stage_monthly)
        expect(subject[:usage_activity_by_stage])
          .to include(:configure, :create, :manage, :monitor, :plan, :release, :verify)
        expect(subject[:usage_activity_by_stage_monthly])
          .to include(:configure, :create, :manage, :monitor, :plan, :release, :verify)
      end

      it 'clears memoized values' do
        values = %i(issue_minimum_id issue_maximum_id
                    project_minimum_id project_maximum_id
                    user_minimum_id user_maximum_id unique_visit_service
                    deployment_minimum_id deployment_maximum_id
                    approval_merge_request_rule_minimum_id
                    approval_merge_request_rule_maximum_id
                    auth_providers)
        values.each do |key|
          expect(described_class).to receive(:clear_memoization).with(key)
        end

        subject
      end

      it 'merge_requests_users is included only in montly counters' do
        expect(subject[:usage_activity_by_stage][:create])
          .not_to include(:merge_requests_users)
        expect(subject[:usage_activity_by_stage_monthly][:create])
          .to include(:merge_requests_users)
      end
    end

    it 'ensures recorded_at is set before any other usage data calculation' do
      %i(alt_usage_data redis_usage_data distinct_count count).each do |method|
        expect(described_class).not_to receive(method)
      end
      expect(described_class).to receive(:recorded_at).and_raise(Exception.new('Stopped calculating recorded_at'))

      expect { described_class.uncached_data }.to raise_error('Stopped calculating recorded_at')
    end
  end

  describe 'usage_activity_by_stage_package' do
    it 'includes accurate usage_activity_by_stage data' do
      for_defined_days_back do
        create(:project, packages: [create(:package)] )
      end

      expect(described_class.usage_activity_by_stage_package({})).to eq(
        projects_with_packages: 2
      )
      expect(described_class.usage_activity_by_stage_package(described_class.last_28_days_time_period)).to eq(
        projects_with_packages: 1
      )
    end
  end

  describe '.usage_activity_by_stage_configure' do
    it 'includes accurate usage_activity_by_stage data' do
      for_defined_days_back do
        user = create(:user)
        cluster = create(:cluster, user: user)
        create(:clusters_applications_cert_manager, :installed, cluster: cluster)
        create(:clusters_applications_helm, :installed, cluster: cluster)
        create(:clusters_applications_ingress, :installed, cluster: cluster)
        create(:clusters_applications_knative, :installed, cluster: cluster)
        create(:cluster, :disabled, user: user)
        create(:cluster_provider_gcp, :created)
        create(:cluster_provider_aws, :created)
        create(:cluster_platform_kubernetes)
        create(:cluster, :group, :disabled, user: user)
        create(:cluster, :group, user: user)
        create(:cluster, :instance, :disabled, :production_environment)
        create(:cluster, :instance, :production_environment)
        create(:cluster, :management_project)
      end

      expect(described_class.usage_activity_by_stage_configure({})).to include(
        clusters_applications_cert_managers: 2,
        clusters_applications_helm: 2,
        clusters_applications_ingress: 2,
        clusters_applications_knative: 2,
        clusters_management_project: 2,
        clusters_disabled: 4,
        clusters_enabled: 12,
        clusters_platforms_gke: 2,
        clusters_platforms_eks: 2,
        clusters_platforms_user: 2,
        instance_clusters_disabled: 2,
        instance_clusters_enabled: 2,
        group_clusters_disabled: 2,
        group_clusters_enabled: 2,
        project_clusters_disabled: 2,
        project_clusters_enabled: 10
      )
      expect(described_class.usage_activity_by_stage_configure(described_class.last_28_days_time_period)).to include(
        clusters_applications_cert_managers: 1,
        clusters_applications_helm: 1,
        clusters_applications_ingress: 1,
        clusters_applications_knative: 1,
        clusters_management_project: 1,
        clusters_disabled: 2,
        clusters_enabled: 6,
        clusters_platforms_gke: 1,
        clusters_platforms_eks: 1,
        clusters_platforms_user: 1,
        instance_clusters_disabled: 1,
        instance_clusters_enabled: 1,
        group_clusters_disabled: 1,
        group_clusters_enabled: 1,
        project_clusters_disabled: 1,
        project_clusters_enabled: 5
      )
    end
  end

  describe 'usage_activity_by_stage_create' do
    it 'includes accurate usage_activity_by_stage data' do
      for_defined_days_back do
        user = create(:user)
        project = create(:project, :repository_private,
                         :test_repo, :remote_mirror, creator: user)
        create(:merge_request, source_project: project)
        create(:deploy_key, user: user)
        create(:key, user: user)
        create(:project, creator: user, disable_overriding_approvers_per_merge_request: true)
        create(:project, creator: user, disable_overriding_approvers_per_merge_request: false)
        create(:remote_mirror, project: project)
        create(:snippet, author: user)
      end

      expect(described_class.usage_activity_by_stage_create({})).to include(
        deploy_keys: 2,
        keys: 2,
        merge_requests: 2,
        projects_with_disable_overriding_approvers_per_merge_request: 2,
        projects_without_disable_overriding_approvers_per_merge_request: 4,
        remote_mirrors: 2,
        snippets: 2
      )
      expect(described_class.usage_activity_by_stage_create(described_class.last_28_days_time_period)).to include(
        deploy_keys: 1,
        keys: 1,
        merge_requests: 1,
        projects_with_disable_overriding_approvers_per_merge_request: 1,
        projects_without_disable_overriding_approvers_per_merge_request: 2,
        remote_mirrors: 1,
        snippets: 1
      )
    end
  end

  describe 'usage_activity_by_stage_manage' do
    it 'includes accurate usage_activity_by_stage data' do
      described_class.clear_memoization(:auth_providers)

      stub_config(
        omniauth:
          { providers: omniauth_providers }
      )

      for_defined_days_back do
        user = create(:user)
        user2 = create(:user)
        create(:event, author: user)
        create(:group_member, user: user)
        create(:authentication_event, user: user, provider: :ldapmain, result: :success)
        create(:authentication_event, user: user2, provider: :ldapsecondary, result: :success)
        create(:authentication_event, user: user2, provider: :group_saml, result: :success)
        create(:authentication_event, user: user2, provider: :group_saml, result: :success)
        create(:authentication_event, user: user, provider: :group_saml, result: :failed)
      end

      expect(described_class.usage_activity_by_stage_manage({})).to include(
        events: 2,
        groups: 2,
        users_created: 6,
        omniauth_providers: ['google_oauth2'],
        user_auth_by_provider: { 'group_saml' => 2, 'ldap' => 4 }
      )
      expect(described_class.usage_activity_by_stage_manage(described_class.last_28_days_time_period)).to include(
        events: 1,
        groups: 1,
        users_created: 3,
        omniauth_providers: ['google_oauth2'],
        user_auth_by_provider: { 'group_saml' => 1, 'ldap' => 2 }
      )
    end

    it 'includes imports usage data' do
      for_defined_days_back do
        user = create(:user)

        %w(gitlab_project gitlab github bitbucket bitbucket_server gitea git manifest fogbugz phabricator).each do |type|
          create(:project, import_type: type, creator_id: user.id)
        end

        jira_project = create(:project, creator_id: user.id)
        create(:jira_import_state, :finished, project: jira_project)
      end

      expect(described_class.usage_activity_by_stage_manage({})).to include(
        {
          projects_imported: {
            gitlab_project: 2,
            gitlab: 2,
            github: 2,
            bitbucket: 2,
            bitbucket_server: 2,
            gitea: 2,
            git: 2,
            manifest: 2
          },
          issues_imported: {
            jira: 2,
            fogbugz: 2,
            phabricator: 2
          }
        }
      )
      expect(described_class.usage_activity_by_stage_manage(described_class.last_28_days_time_period)).to include(
        {
          projects_imported: {
            gitlab_project: 1,
            gitlab: 1,
            github: 1,
            bitbucket: 1,
            bitbucket_server: 1,
            gitea: 1,
            git: 1,
            manifest: 1
          },
          issues_imported: {
            jira: 1,
            fogbugz: 1,
            phabricator: 1
          }
        }
      )
    end

    def omniauth_providers
      [
        OpenStruct.new(name: 'google_oauth2'),
        OpenStruct.new(name: 'ldapmain'),
        OpenStruct.new(name: 'group_saml')
      ]
    end
  end

  describe 'usage_activity_by_stage_monitor' do
    it 'includes accurate usage_activity_by_stage data' do
      for_defined_days_back do
        user    = create(:user, dashboard: 'operations')
        cluster = create(:cluster, user: user)
        create(:project, creator: user)
        create(:clusters_applications_prometheus, :installed, cluster: cluster)
      end

      expect(described_class.usage_activity_by_stage_monitor({})).to include(
        clusters: 2,
        clusters_applications_prometheus: 2,
        operations_dashboard_default_dashboard: 2
      )
      expect(described_class.usage_activity_by_stage_monitor(described_class.last_28_days_time_period)).to include(
        clusters: 1,
        clusters_applications_prometheus: 1,
        operations_dashboard_default_dashboard: 1
      )
    end
  end

  describe 'usage_activity_by_stage_plan' do
    it 'includes accurate usage_activity_by_stage data' do
      for_defined_days_back do
        user = create(:user)
        project = create(:project, creator: user)
        issue = create(:issue, project: project, author: user)
        create(:issue, project: project, author: User.support_bot)
        create(:note, project: project, noteable: issue, author: user)
        create(:todo, project: project, target: issue, author: user)
        create(:jira_service, :jira_cloud_service, active: true, project: create(:project, :jira_dvcs_cloud, creator: user))
        create(:jira_service, active: true, project: create(:project, :jira_dvcs_server, creator: user))
      end

      expect(described_class.usage_activity_by_stage_plan({})).to include(
        issues: 3,
        notes: 2,
        projects: 2,
        todos: 2,
        service_desk_enabled_projects: 2,
        service_desk_issues: 2,
        projects_jira_active: 2,
        projects_jira_dvcs_cloud_active: 2,
        projects_jira_dvcs_server_active: 2
      )
      expect(described_class.usage_activity_by_stage_plan(described_class.last_28_days_time_period)).to include(
        issues: 2,
        notes: 1,
        projects: 1,
        todos: 1,
        service_desk_enabled_projects: 1,
        service_desk_issues: 1,
        projects_jira_active: 1,
        projects_jira_dvcs_cloud_active: 1,
        projects_jira_dvcs_server_active: 1
      )
    end
  end

  describe 'usage_activity_by_stage_release' do
    it 'includes accurate usage_activity_by_stage data' do
      for_defined_days_back do
        user = create(:user)
        create(:deployment, :failed, user: user)
        create(:release, author: user)
        create(:deployment, :success, user: user)
      end

      expect(described_class.usage_activity_by_stage_release({})).to include(
        deployments: 2,
        failed_deployments: 2,
        releases: 2,
        successful_deployments: 2
      )
      expect(described_class.usage_activity_by_stage_release(described_class.last_28_days_time_period)).to include(
        deployments: 1,
        failed_deployments: 1,
        releases: 1,
        successful_deployments: 1
      )
    end
  end

  describe 'usage_activity_by_stage_verify' do
    it 'includes accurate usage_activity_by_stage data' do
      for_defined_days_back do
        user = create(:user)
        create(:ci_build, user: user)
        create(:ci_empty_pipeline, source: :external, user: user)
        create(:ci_empty_pipeline, user: user)
        create(:ci_pipeline, :auto_devops_source, user: user)
        create(:ci_pipeline, :repository_source, user: user)
        create(:ci_pipeline_schedule, owner: user)
        create(:ci_trigger, owner: user)
        create(:clusters_applications_runner, :installed)
      end

      expect(described_class.usage_activity_by_stage_verify({})).to include(
        ci_builds: 2,
        ci_external_pipelines: 2,
        ci_internal_pipelines: 2,
        ci_pipeline_config_auto_devops: 2,
        ci_pipeline_config_repository: 2,
        ci_pipeline_schedules: 2,
        ci_pipelines: 2,
        ci_triggers: 2,
        clusters_applications_runner: 2
      )
      expect(described_class.usage_activity_by_stage_verify(described_class.last_28_days_time_period)).to include(
        ci_builds: 1,
        ci_external_pipelines: 1,
        ci_internal_pipelines: 1,
        ci_pipeline_config_auto_devops: 1,
        ci_pipeline_config_repository: 1,
        ci_pipeline_schedules: 1,
        ci_pipelines: 1,
        ci_triggers: 1,
        clusters_applications_runner: 1
      )
    end
  end

  describe '.data' do
    let!(:ud) { build(:usage_data) }

    before do
      allow(described_class).to receive(:grafana_embed_usage_data).and_return(2)
    end

    subject { described_class.data }

    it 'gathers usage data' do
      expect(subject.keys).to include(*UsageDataHelpers::USAGE_DATA_KEYS)
    end

    it 'gathers usage counts' do
      count_data = subject[:counts]

      expect(count_data[:boards]).to eq(1)
      expect(count_data[:projects]).to eq(4)
      expect(count_data.values_at(*UsageDataHelpers::SMAU_KEYS)).to all(be_an(Integer))
      expect(count_data.keys).to include(*UsageDataHelpers::COUNTS_KEYS)
      expect(UsageDataHelpers::COUNTS_KEYS - count_data.keys).to be_empty
    end

    it 'gathers usage counts correctly' do
      count_data = subject[:counts]

      expect(count_data[:projects]).to eq(4)
      expect(count_data[:projects_asana_active]).to eq(0)
      expect(count_data[:projects_prometheus_active]).to eq(1)
      expect(count_data[:projects_jira_active]).to eq(4)
      expect(count_data[:projects_jira_server_active]).to eq(2)
      expect(count_data[:projects_jira_cloud_active]).to eq(2)
      expect(count_data[:jira_imports_projects_count]).to eq(2)
      expect(count_data[:jira_imports_total_imported_count]).to eq(3)
      expect(count_data[:jira_imports_total_imported_issues_count]).to eq(13)
      expect(count_data[:projects_slack_active]).to eq(2)
      expect(count_data[:projects_slack_slash_commands_active]).to eq(1)
      expect(count_data[:projects_custom_issue_tracker_active]).to eq(1)
      expect(count_data[:projects_mattermost_active]).to eq(1)
      expect(count_data[:templates_mattermost_active]).to eq(1)
      expect(count_data[:instances_mattermost_active]).to eq(1)
      expect(count_data[:projects_inheriting_instance_mattermost_active]).to eq(1)
      expect(count_data[:projects_with_repositories_enabled]).to eq(3)
      expect(count_data[:projects_with_error_tracking_enabled]).to eq(1)
      expect(count_data[:projects_with_alerts_service_enabled]).to eq(1)
      expect(count_data[:projects_with_prometheus_alerts]).to eq(2)
      expect(count_data[:projects_with_terraform_reports]).to eq(2)
      expect(count_data[:projects_with_terraform_states]).to eq(2)
      expect(count_data[:protected_branches]).to eq(2)
      expect(count_data[:protected_branches_except_default]).to eq(1)
      expect(count_data[:terraform_reports]).to eq(6)
      expect(count_data[:terraform_states]).to eq(3)
      expect(count_data[:issues_created_from_gitlab_error_tracking_ui]).to eq(1)
      expect(count_data[:issues_with_associated_zoom_link]).to eq(2)
      expect(count_data[:issues_using_zoom_quick_actions]).to eq(3)
      expect(count_data[:issues_with_embedded_grafana_charts_approx]).to eq(2)
      expect(count_data[:incident_issues]).to eq(4)
      expect(count_data[:issues_created_gitlab_alerts]).to eq(1)
      expect(count_data[:issues_created_from_alerts]).to eq(3)
      expect(count_data[:issues_created_manually_from_alerts]).to eq(1)
      expect(count_data[:alert_bot_incident_issues]).to eq(4)
      expect(count_data[:incident_labeled_issues]).to eq(3)

      expect(count_data[:clusters_enabled]).to eq(6)
      expect(count_data[:project_clusters_enabled]).to eq(4)
      expect(count_data[:group_clusters_enabled]).to eq(1)
      expect(count_data[:instance_clusters_enabled]).to eq(1)
      expect(count_data[:clusters_disabled]).to eq(3)
      expect(count_data[:project_clusters_disabled]).to eq(1)
      expect(count_data[:group_clusters_disabled]).to eq(1)
      expect(count_data[:instance_clusters_disabled]).to eq(1)
      expect(count_data[:clusters_platforms_eks]).to eq(1)
      expect(count_data[:clusters_platforms_gke]).to eq(1)
      expect(count_data[:clusters_platforms_user]).to eq(1)
      expect(count_data[:clusters_applications_helm]).to eq(1)
      expect(count_data[:clusters_applications_ingress]).to eq(1)
      expect(count_data[:clusters_applications_cert_managers]).to eq(1)
      expect(count_data[:clusters_applications_crossplane]).to eq(1)
      expect(count_data[:clusters_applications_prometheus]).to eq(1)
      expect(count_data[:clusters_applications_runner]).to eq(1)
      expect(count_data[:clusters_applications_knative]).to eq(1)
      expect(count_data[:clusters_applications_elastic_stack]).to eq(1)
      expect(count_data[:grafana_integrated_projects]).to eq(2)
      expect(count_data[:clusters_applications_jupyter]).to eq(1)
      expect(count_data[:clusters_applications_cilium]).to eq(1)
      expect(count_data[:clusters_management_project]).to eq(1)
      expect(count_data[:kubernetes_agents]).to eq(2)
      expect(count_data[:kubernetes_agents_with_token]).to eq(1)

      expect(count_data[:deployments]).to eq(4)
      expect(count_data[:successful_deployments]).to eq(2)
      expect(count_data[:failed_deployments]).to eq(2)
      expect(count_data[:snippets]).to eq(6)
      expect(count_data[:personal_snippets]).to eq(2)
      expect(count_data[:project_snippets]).to eq(4)

      expect(count_data[:projects_with_packages]).to eq(2)
      expect(count_data[:packages]).to eq(4)
    end

    it 'gathers object store usage correctly' do
      expect(subject[:object_store]).to eq(
        { artifacts: { enabled: true, object_store: { enabled: true, direct_upload: true, background_upload: false, provider: "AWS" } },
         external_diffs: { enabled: false },
         lfs: { enabled: true, object_store: { enabled: false, direct_upload: true, background_upload: false, provider: "AWS" } },
         uploads: { enabled: nil, object_store: { enabled: false, direct_upload: true, background_upload: false, provider: "AWS" } },
         packages: { enabled: true, object_store: { enabled: false, direct_upload: false, background_upload: true, provider: "AWS" } } }
      )
    end

    context 'with existing container expiration policies' do
      let_it_be(:disabled) { create(:container_expiration_policy, enabled: false) }
      let_it_be(:enabled) { create(:container_expiration_policy, enabled: true) }

      %i[keep_n cadence older_than].each do |attribute|
        ContainerExpirationPolicy.send("#{attribute}_options").keys.each do |value|
          let_it_be("container_expiration_policy_with_#{attribute}_set_to_#{value}") { create(:container_expiration_policy, attribute => value) }
        end
      end

      let_it_be('container_expiration_policy_with_keep_n_set_to_null') { create(:container_expiration_policy, keep_n: nil) }
      let_it_be('container_expiration_policy_with_older_than_set_to_null') { create(:container_expiration_policy, older_than: nil) }

      let(:inactive_policies) { ::ContainerExpirationPolicy.where(enabled: false) }
      let(:active_policies) { ::ContainerExpirationPolicy.active }

      subject { described_class.data[:counts] }

      it 'gathers usage data' do
        expect(subject[:projects_with_expiration_policy_enabled]).to eq 22
        expect(subject[:projects_with_expiration_policy_disabled]).to eq 1

        expect(subject[:projects_with_expiration_policy_enabled_with_keep_n_unset]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_keep_n_set_to_1]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_keep_n_set_to_5]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_keep_n_set_to_10]).to eq 16
        expect(subject[:projects_with_expiration_policy_enabled_with_keep_n_set_to_25]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_keep_n_set_to_50]).to eq 1

        expect(subject[:projects_with_expiration_policy_enabled_with_older_than_unset]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_older_than_set_to_7d]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_older_than_set_to_14d]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_older_than_set_to_30d]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_older_than_set_to_90d]).to eq 18

        expect(subject[:projects_with_expiration_policy_enabled_with_cadence_set_to_1d]).to eq 18
        expect(subject[:projects_with_expiration_policy_enabled_with_cadence_set_to_7d]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_cadence_set_to_14d]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_cadence_set_to_1month]).to eq 1
        expect(subject[:projects_with_expiration_policy_enabled_with_cadence_set_to_3month]).to eq 1
      end
    end

    it 'works when queries time out' do
      allow_any_instance_of(ActiveRecord::Relation)
        .to receive(:count).and_raise(ActiveRecord::StatementInvalid.new(''))

      expect { subject }.not_to raise_error
    end

    it 'includes a recording_ce_finished_at timestamp' do
      expect(subject[:recording_ce_finished_at]).to be_a(Time)
    end

    it 'jira usage works when queries time out' do
      allow_any_instance_of(ActiveRecord::Relation)
        .to receive(:find_in_batches).and_raise(ActiveRecord::StatementInvalid.new(''))

      expect { described_class.jira_usage }.not_to raise_error
    end
  end

  describe '.system_usage_data_monthly' do
    let!(:ud) { build(:usage_data) }

    subject { described_class.system_usage_data_monthly }

    it 'gathers monthly usage counts correctly' do
      counts_monthly = subject[:counts_monthly]

      expect(counts_monthly[:deployments]).to eq(2)
      expect(counts_monthly[:successful_deployments]).to eq(1)
      expect(counts_monthly[:failed_deployments]).to eq(1)
      expect(counts_monthly[:snippets]).to eq(3)
      expect(counts_monthly[:personal_snippets]).to eq(1)
      expect(counts_monthly[:project_snippets]).to eq(2)
      expect(counts_monthly[:packages]).to eq(3)
    end
  end

  describe '.usage_counters' do
    subject { described_class.usage_counters }

    it { is_expected.to include(:kubernetes_agent_gitops_sync) }
  end

  describe '.usage_data_counters' do
    subject { described_class.usage_data_counters }

    it { is_expected.to all(respond_to :totals) }
    it { is_expected.to all(respond_to :fallback_totals) }

    describe 'the results of calling #totals on all objects in the array' do
      subject { described_class.usage_data_counters.map(&:totals) }

      it { is_expected.to all(be_a Hash) }
      it { is_expected.to all(have_attributes(keys: all(be_a Symbol), values: all(be_a Integer))) }
    end

    describe 'the results of calling #fallback_totals on all objects in the array' do
      subject { described_class.usage_data_counters.map(&:fallback_totals) }

      it { is_expected.to all(be_a Hash) }
      it { is_expected.to all(have_attributes(keys: all(be_a Symbol), values: all(eq(-1)))) }
    end

    it 'does not have any conflicts' do
      all_keys = subject.flat_map { |counter| counter.totals.keys }

      expect(all_keys.size).to eq all_keys.to_set.size
    end
  end

  describe '.license_usage_data' do
    subject { described_class.license_usage_data }

    it 'gathers license data' do
      expect(subject[:uuid]).to eq(Gitlab::CurrentSettings.uuid)
      expect(subject[:version]).to eq(Gitlab::VERSION)
      expect(subject[:installation_type]).to eq('gitlab-development-kit')
      expect(subject[:active_user_count]).to eq(User.active.size)
      expect(subject[:recorded_at]).to be_a(Time)
    end
  end

  context 'when not relying on database records' do
    describe '.features_usage_data_ce' do
      subject { described_class.features_usage_data_ce }

      it 'gathers feature usage data', :aggregate_failures do
        expect(subject[:instance_auto_devops_enabled]).to eq(Gitlab::CurrentSettings.auto_devops_enabled?)
        expect(subject[:mattermost_enabled]).to eq(Gitlab.config.mattermost.enabled)
        expect(subject[:signup_enabled]).to eq(Gitlab::CurrentSettings.allow_signup?)
        expect(subject[:ldap_enabled]).to eq(Gitlab.config.ldap.enabled)
        expect(subject[:gravatar_enabled]).to eq(Gitlab::CurrentSettings.gravatar_enabled?)
        expect(subject[:omniauth_enabled]).to eq(Gitlab::Auth.omniauth_enabled?)
        expect(subject[:reply_by_email_enabled]).to eq(Gitlab::IncomingEmail.enabled?)
        expect(subject[:container_registry_enabled]).to eq(Gitlab.config.registry.enabled)
        expect(subject[:dependency_proxy_enabled]).to eq(Gitlab.config.dependency_proxy.enabled)
        expect(subject[:gitlab_shared_runners_enabled]).to eq(Gitlab.config.gitlab_ci.shared_runners_enabled)
        expect(subject[:web_ide_clientside_preview_enabled]).to eq(Gitlab::CurrentSettings.web_ide_clientside_preview_enabled?)
        expect(subject[:grafana_link_enabled]).to eq(Gitlab::CurrentSettings.grafana_enabled?)
        expect(subject[:gitpod_enabled]).to eq(Gitlab::CurrentSettings.gitpod_enabled?)
      end

      context 'with embedded Prometheus' do
        it 'returns true when embedded Prometheus is enabled' do
          allow(Gitlab::Prometheus::Internal).to receive(:prometheus_enabled?).and_return(true)

          expect(subject[:prometheus_enabled]).to eq(true)
        end

        it 'returns false when embedded Prometheus is disabled' do
          allow(Gitlab::Prometheus::Internal).to receive(:prometheus_enabled?).and_return(false)

          expect(subject[:prometheus_enabled]).to eq(false)
        end
      end

      context 'with embedded grafana' do
        it 'returns true when embedded grafana is enabled' do
          stub_application_setting(grafana_enabled: true)

          expect(subject[:grafana_link_enabled]).to eq(true)
        end

        it 'returns false when embedded grafana is disabled' do
          stub_application_setting(grafana_enabled: false)

          expect(subject[:grafana_link_enabled]).to eq(false)
        end
      end

      context 'with Gitpod' do
        it 'returns true when is enabled' do
          stub_application_setting(gitpod_enabled: true)

          expect(subject[:gitpod_enabled]).to eq(true)
        end

        it 'returns false when is disabled' do
          stub_application_setting(gitpod_enabled: false)

          expect(subject[:gitpod_enabled]).to eq(false)
        end
      end
    end

    describe '.components_usage_data' do
      subject { described_class.components_usage_data }

      it 'gathers basic components usage data' do
        stub_application_setting(container_registry_vendor: 'gitlab', container_registry_version: 'x.y.z')

        expect(subject[:gitlab_pages][:enabled]).to eq(Gitlab.config.pages.enabled)
        expect(subject[:gitlab_pages][:version]).to eq(Gitlab::Pages::VERSION)
        expect(subject[:git][:version]).to eq(Gitlab::Git.version)
        expect(subject[:database][:adapter]).to eq(Gitlab::Database.adapter_name)
        expect(subject[:database][:version]).to eq(Gitlab::Database.version)
        expect(subject[:mail][:smtp_server]).to eq(ActionMailer::Base.smtp_settings[:address])
        expect(subject[:gitaly][:version]).to be_present
        expect(subject[:gitaly][:servers]).to be >= 1
        expect(subject[:gitaly][:clusters]).to be >= 0
        expect(subject[:gitaly][:filesystems]).to be_an(Array)
        expect(subject[:gitaly][:filesystems].first).to be_a(String)
        expect(subject[:container_registry_server][:vendor]).to eq('gitlab')
        expect(subject[:container_registry_server][:version]).to eq('x.y.z')
      end
    end

    describe '.object_store_config' do
      let(:component) { 'lfs' }

      subject { described_class.object_store_config(component) }

      context 'when object_store is not configured' do
        it 'returns component enable status only' do
          allow(Settings).to receive(:[]).with(component).and_return({ 'enabled' => false })

          expect(subject).to eq({ enabled: false })
        end
      end

      context 'when object_store is configured' do
        it 'returns filtered object store config' do
          allow(Settings).to receive(:[]).with(component)
            .and_return(
              { 'enabled' => true,
                'object_store' =>
                { 'enabled' => true,
                  'remote_directory' => component,
                  'direct_upload' => true,
                  'connection' =>
                { 'provider' => 'AWS', 'aws_access_key_id' => 'minio', 'aws_secret_access_key' => 'gdk-minio', 'region' => 'gdk', 'endpoint' => 'http://127.0.0.1:9000', 'path_style' => true },
                  'background_upload' => false,
                  'proxy_download' => false } })

          expect(subject).to eq(
            { enabled: true, object_store: { enabled: true, direct_upload: true, background_upload: false, provider: "AWS" } })
        end
      end

      context 'when retrieve component setting meets exception' do
        it 'returns -1 for component enable status' do
          allow(Settings).to receive(:[]).with(component).and_raise(StandardError)

          expect(subject).to eq({ enabled: -1 })
        end
      end
    end

    describe '.object_store_usage_data' do
      subject { described_class.object_store_usage_data }

      it 'fetches object store config of five components' do
        %w(artifacts external_diffs lfs uploads packages).each do |component|
          expect(described_class).to receive(:object_store_config).with(component).and_return("#{component}_object_store_config")
        end

        expect(subject).to eq(
          object_store: {
            artifacts: 'artifacts_object_store_config',
            external_diffs: 'external_diffs_object_store_config',
            lfs: 'lfs_object_store_config',
            uploads: 'uploads_object_store_config',
            packages: 'packages_object_store_config'
          })
      end
    end

    describe '.cycle_analytics_usage_data' do
      subject { described_class.cycle_analytics_usage_data }

      it 'works when queries time out in new' do
        allow(Gitlab::CycleAnalytics::UsageData)
          .to receive(:new).and_raise(ActiveRecord::StatementInvalid.new(''))

        expect { subject }.not_to raise_error
      end

      it 'works when queries time out in to_json' do
        allow_any_instance_of(Gitlab::CycleAnalytics::UsageData)
          .to receive(:to_json).and_raise(ActiveRecord::StatementInvalid.new(''))

        expect { subject }.not_to raise_error
      end
    end

    describe '.ingress_modsecurity_usage' do
      subject { described_class.ingress_modsecurity_usage }

      let(:environment) { create(:environment) }
      let(:project) { environment.project }
      let(:environment_scope) { '*' }
      let(:deployment) { create(:deployment, :success, environment: environment, project: project, cluster: cluster) }
      let(:cluster) { create(:cluster, environment_scope: environment_scope, projects: [project]) }
      let(:ingress_mode) { :modsecurity_blocking }
      let!(:ingress) { create(:clusters_applications_ingress, ingress_mode, cluster: cluster) }

      context 'when cluster is disabled' do
        let(:cluster) { create(:cluster, :disabled, projects: [project]) }

        it 'gathers ingress data' do
          expect(subject[:ingress_modsecurity_logging]).to eq(0)
          expect(subject[:ingress_modsecurity_blocking]).to eq(0)
          expect(subject[:ingress_modsecurity_disabled]).to eq(0)
          expect(subject[:ingress_modsecurity_not_installed]).to eq(0)
        end
      end

      context 'when deployment is unsuccessful' do
        let!(:deployment) { create(:deployment, :failed, environment: environment, project: project, cluster: cluster) }

        it 'gathers ingress data' do
          expect(subject[:ingress_modsecurity_logging]).to eq(0)
          expect(subject[:ingress_modsecurity_blocking]).to eq(0)
          expect(subject[:ingress_modsecurity_disabled]).to eq(0)
          expect(subject[:ingress_modsecurity_not_installed]).to eq(0)
        end
      end

      context 'when deployment is successful' do
        let!(:deployment) { create(:deployment, :success, environment: environment, project: project, cluster: cluster) }

        context 'when modsecurity is in blocking mode' do
          it 'gathers ingress data' do
            expect(subject[:ingress_modsecurity_logging]).to eq(0)
            expect(subject[:ingress_modsecurity_blocking]).to eq(1)
            expect(subject[:ingress_modsecurity_disabled]).to eq(0)
            expect(subject[:ingress_modsecurity_not_installed]).to eq(0)
          end
        end

        context 'when modsecurity is in logging mode' do
          let(:ingress_mode) { :modsecurity_logging }

          it 'gathers ingress data' do
            expect(subject[:ingress_modsecurity_logging]).to eq(1)
            expect(subject[:ingress_modsecurity_blocking]).to eq(0)
            expect(subject[:ingress_modsecurity_disabled]).to eq(0)
            expect(subject[:ingress_modsecurity_not_installed]).to eq(0)
          end
        end

        context 'when modsecurity is disabled' do
          let(:ingress_mode) { :modsecurity_disabled }

          it 'gathers ingress data' do
            expect(subject[:ingress_modsecurity_logging]).to eq(0)
            expect(subject[:ingress_modsecurity_blocking]).to eq(0)
            expect(subject[:ingress_modsecurity_disabled]).to eq(1)
            expect(subject[:ingress_modsecurity_not_installed]).to eq(0)
          end
        end

        context 'when modsecurity is not installed' do
          let(:ingress_mode) { :modsecurity_not_installed }

          it 'gathers ingress data' do
            expect(subject[:ingress_modsecurity_logging]).to eq(0)
            expect(subject[:ingress_modsecurity_blocking]).to eq(0)
            expect(subject[:ingress_modsecurity_disabled]).to eq(0)
            expect(subject[:ingress_modsecurity_not_installed]).to eq(1)
          end
        end

        context 'with multiple projects' do
          let(:environment_2) { create(:environment) }
          let(:project_2) { environment_2.project }
          let(:cluster_2) { create(:cluster, environment_scope: environment_scope, projects: [project_2]) }
          let!(:ingress_2) { create(:clusters_applications_ingress, :modsecurity_logging, cluster: cluster_2) }
          let!(:deployment_2) { create(:deployment, :success, environment: environment_2, project: project_2, cluster: cluster_2) }

          it 'gathers non-duplicated ingress data' do
            expect(subject[:ingress_modsecurity_logging]).to eq(1)
            expect(subject[:ingress_modsecurity_blocking]).to eq(1)
            expect(subject[:ingress_modsecurity_disabled]).to eq(0)
            expect(subject[:ingress_modsecurity_not_installed]).to eq(0)
          end
        end

        context 'with multiple deployments' do
          let!(:deployment_2) { create(:deployment, :success, environment: environment, project: project, cluster: cluster) }

          it 'gathers non-duplicated ingress data' do
            expect(subject[:ingress_modsecurity_logging]).to eq(0)
            expect(subject[:ingress_modsecurity_blocking]).to eq(1)
            expect(subject[:ingress_modsecurity_disabled]).to eq(0)
            expect(subject[:ingress_modsecurity_not_installed]).to eq(0)
          end
        end

        context 'with multiple projects' do
          let(:environment_2) { create(:environment) }
          let(:project_2) { environment_2.project }
          let!(:deployment_2) { create(:deployment, :success, environment: environment_2, project: project_2, cluster: cluster) }
          let(:cluster) { create(:cluster, environment_scope: environment_scope, projects: [project, project_2]) }

          it 'gathers ingress data' do
            expect(subject[:ingress_modsecurity_logging]).to eq(0)
            expect(subject[:ingress_modsecurity_blocking]).to eq(2)
            expect(subject[:ingress_modsecurity_disabled]).to eq(0)
            expect(subject[:ingress_modsecurity_not_installed]).to eq(0)
          end
        end

        context 'with multiple environments' do
          let!(:environment_2) { create(:environment, project: project) }
          let!(:deployment_2) { create(:deployment, :success, environment: environment_2, project: project, cluster: cluster) }

          it 'gathers ingress data' do
            expect(subject[:ingress_modsecurity_logging]).to eq(0)
            expect(subject[:ingress_modsecurity_blocking]).to eq(2)
            expect(subject[:ingress_modsecurity_disabled]).to eq(0)
            expect(subject[:ingress_modsecurity_not_installed]).to eq(0)
          end
        end
      end
    end

    describe '.grafana_embed_usage_data' do
      subject { described_class.grafana_embed_usage_data }

      let(:project) { create(:project) }
      let(:description_with_embed) { "Some comment\n\nhttps://grafana.example.com/d/xvAk4q0Wk/go-processes?orgId=1&from=1573238522762&to=1573240322762&var-job=prometheus&var-interval=10m&panelId=1&fullscreen" }
      let(:description_with_unintegrated_embed) { "Some comment\n\nhttps://grafana.exp.com/d/xvAk4q0Wk/go-processes?orgId=1&from=1573238522762&to=1573240322762&var-job=prometheus&var-interval=10m&panelId=1&fullscreen" }
      let(:description_with_non_grafana_inline_metric) { "Some comment\n\n#{Gitlab::Routing.url_helpers.metrics_namespace_project_environment_url(*['foo', 'bar', 12])}" }

      shared_examples "zero count" do
        it "does not count the issue" do
          expect(subject).to eq(0)
        end
      end

      context 'with project grafana integration enabled' do
        before do
          create(:grafana_integration, project: project, enabled: true)
        end

        context 'with valid and invalid embeds' do
          before do
            # Valid
            create(:issue, project: project, description: description_with_embed)
            create(:issue, project: project, description: description_with_embed)
            # In-Valid
            create(:issue, project: project, description: description_with_unintegrated_embed)
            create(:issue, project: project, description: description_with_non_grafana_inline_metric)
            create(:issue, project: project, description: nil)
            create(:issue, project: project, description: '')
            create(:issue, project: project)
          end

          it 'counts only the issues with embeds' do
            expect(subject).to eq(2)
          end
        end
      end

      context 'with project grafana integration disabled' do
        before do
          create(:grafana_integration, project: project, enabled: false)
        end

        context 'with one issue having a grafana link in the description and one without' do
          before do
            create(:issue, project: project, description: description_with_embed)
            create(:issue, project: project)
          end

          it_behaves_like('zero count')
        end
      end

      context 'with an un-integrated project' do
        context 'with one issue having a grafana link in the description and one without' do
          before do
            create(:issue, project: project, description: description_with_embed)
            create(:issue, project: project)
          end

          it_behaves_like('zero count')
        end
      end
    end
  end

  describe '.merge_requests_users', :clean_gitlab_redis_shared_state do
    let(:time_period) { { created_at: 2.days.ago..time } }
    let(:time) { Time.current }

    before do
      counter = Gitlab::UsageDataCounters::TrackUniqueEvents
      merge_request = Event::TARGET_TYPES[:merge_request]
      design = Event::TARGET_TYPES[:design]

      counter.track_event(event_action: :commented, event_target: merge_request, author_id: 1, time: time)
      counter.track_event(event_action: :opened, event_target: merge_request, author_id: 1, time: time)
      counter.track_event(event_action: :merged, event_target: merge_request, author_id: 2, time: time)
      counter.track_event(event_action: :closed, event_target: merge_request, author_id: 3, time: time)
      counter.track_event(event_action: :opened, event_target: merge_request, author_id: 4, time: time - 3.days)
      counter.track_event(event_action: :created, event_target: design, author_id: 5, time: time)
    end

    it 'returns the distinct count of users using merge requests (via events table) within the specified time period' do
      expect(described_class.merge_requests_users(time_period)).to eq(3)
    end
  end

  def for_defined_days_back(days: [29, 2])
    days.each do |n|
      Timecop.travel(n.days.ago) do
        yield
      end
    end
  end

  describe '#action_monthly_active_users', :clean_gitlab_redis_shared_state do
    let(:time_period) { { created_at: 2.days.ago..time } }
    let(:time) { Time.zone.now }
    let(:user1) { build(:user, id: 1) }
    let(:user2) { build(:user, id: 2) }
    let(:user3) { build(:user, id: 3) }

    before do
      counter = Gitlab::UsageDataCounters::TrackUniqueEvents
      project = Event::TARGET_TYPES[:project]
      wiki = Event::TARGET_TYPES[:wiki]
      design = Event::TARGET_TYPES[:design]

      counter.track_event(event_action: :pushed, event_target: project, author_id: 1)
      counter.track_event(event_action: :pushed, event_target: project, author_id: 1)
      counter.track_event(event_action: :pushed, event_target: project, author_id: 2)
      counter.track_event(event_action: :pushed, event_target: project, author_id: 3)
      counter.track_event(event_action: :pushed, event_target: project, author_id: 4, time: time - 3.days)
      counter.track_event(event_action: :created, event_target: wiki, author_id: 3)
      counter.track_event(event_action: :created, event_target: design, author_id: 3)

      counter = Gitlab::UsageDataCounters::EditorUniqueCounter

      counter.track_web_ide_edit_action(author: user1)
      counter.track_web_ide_edit_action(author: user1)
      counter.track_sfe_edit_action(author: user1)
      counter.track_snippet_editor_edit_action(author: user1)
      counter.track_snippet_editor_edit_action(author: user1, time: time - 3.days)

      counter.track_web_ide_edit_action(author: user2)
      counter.track_sfe_edit_action(author: user2)

      counter.track_web_ide_edit_action(author: user3, time: time - 3.days)
      counter.track_snippet_editor_edit_action(author: user3)
    end

    it 'returns the distinct count of user actions within the specified time period' do
      expect(described_class.action_monthly_active_users(time_period)).to eq(
        {
          action_monthly_active_users_design_management: 1,
          action_monthly_active_users_project_repo: 3,
          action_monthly_active_users_wiki_repo: 1,
          action_monthly_active_users_web_ide_edit: 2,
          action_monthly_active_users_sfe_edit: 2,
          action_monthly_active_users_snippet_editor_edit: 2,
          action_monthly_active_users_ide_edit: 3
        }
      )
    end
  end

  describe '.analytics_unique_visits_data' do
    subject { described_class.analytics_unique_visits_data }

    it 'returns the number of unique visits to pages with analytics features' do
      ::Gitlab::Analytics::UniqueVisits.analytics_events.each do |target|
        expect_any_instance_of(::Gitlab::Analytics::UniqueVisits).to receive(:unique_visits_for).with(targets: target).and_return(123)
      end

      expect_any_instance_of(::Gitlab::Analytics::UniqueVisits).to receive(:unique_visits_for).with(targets: :analytics).and_return(543)
      expect_any_instance_of(::Gitlab::Analytics::UniqueVisits).to receive(:unique_visits_for).with(targets: :analytics, start_date: 4.weeks.ago.to_date, end_date: Date.current).and_return(987)

      expect(subject).to eq({
        analytics_unique_visits: {
          'g_analytics_contribution' => 123,
          'g_analytics_insights' => 123,
          'g_analytics_issues' => 123,
          'g_analytics_productivity' => 123,
          'g_analytics_valuestream' => 123,
          'p_analytics_pipelines' => 123,
          'p_analytics_code_reviews' => 123,
          'p_analytics_valuestream' => 123,
          'p_analytics_insights' => 123,
          'p_analytics_issues' => 123,
          'p_analytics_repo' => 123,
          'i_analytics_cohorts' => 123,
          'i_analytics_dev_ops_score' => 123,
          'i_analytics_instance_statistics' => 123,
          'p_analytics_merge_request' => 123,
          'g_analytics_merge_request' => 123,
          'analytics_unique_visits_for_any_target' => 543,
          'analytics_unique_visits_for_any_target_monthly' => 987
        }
      })
    end
  end

  describe '.compliance_unique_visits_data' do
    subject { described_class.compliance_unique_visits_data }

    before do
      described_class.clear_memoization(:unique_visit_service)

      allow_next_instance_of(::Gitlab::Analytics::UniqueVisits) do |instance|
        ::Gitlab::Analytics::UniqueVisits.compliance_events.each do |target|
          allow(instance).to receive(:unique_visits_for).with(targets: target).and_return(123)
        end

        allow(instance).to receive(:unique_visits_for).with(targets: :compliance).and_return(543)

        allow(instance).to receive(:unique_visits_for).with(targets: :compliance, start_date: 4.weeks.ago.to_date, end_date: Date.current).and_return(987)
      end
    end

    it 'returns the number of unique visits to pages with compliance features' do
      expect(subject).to eq({
        compliance_unique_visits: {
          'g_compliance_dashboard' => 123,
          'g_compliance_audit_events' => 123,
          'i_compliance_credential_inventory' => 123,
          'i_compliance_audit_events' => 123,
          'a_compliance_audit_events_api' => 123,
          'compliance_unique_visits_for_any_target' => 543,
          'compliance_unique_visits_for_any_target_monthly' => 987
        }
      })
    end
  end

  describe '.search_unique_visits_data' do
    subject { described_class.search_unique_visits_data }

    before do
      described_class.clear_memoization(:unique_visit_service)
      events = ::Gitlab::UsageDataCounters::HLLRedisCounter.events_for_category('search')
      events.each do |event|
        allow(::Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:unique_events).with(event_names: event, start_date: 7.days.ago.to_date, end_date: Date.current).and_return(123)
      end
      allow(::Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:unique_events).with(event_names: events, start_date: 7.days.ago.to_date, end_date: Date.current).and_return(543)
      allow(::Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:unique_events).with(event_names: events, start_date: 4.weeks.ago.to_date, end_date: Date.current).and_return(987)
    end

    it 'returns the number of unique visits to pages with search features' do
      expect(subject).to eq({
        search_unique_visits: {
          'i_search_total' => 123,
          'i_search_advanced' => 123,
          'i_search_paid' => 123,
          'search_unique_visits_for_any_target_weekly' => 543,
          'search_unique_visits_for_any_target_monthly' => 987
        }
      })
    end
  end

  describe 'redis_hll_counters' do
    subject { described_class.redis_hll_counters }

    let(:categories) { ::Gitlab::UsageDataCounters::HLLRedisCounter.categories }
    let(:ineligible_total_categories) { ['source_code'] }

    it 'has all know_events' do
      expect(subject).to have_key(:redis_hll_counters)

      expect(subject[:redis_hll_counters].keys).to match_array(categories)

      categories.each do |category|
        keys = ::Gitlab::UsageDataCounters::HLLRedisCounter.events_for_category(category)

        if ineligible_total_categories.exclude?(category)
          keys.append("#{category}_total_unique_counts_weekly", "#{category}_total_unique_counts_monthly")
        end

        expect(subject[:redis_hll_counters][category].keys).to match_array(keys)
      end
    end
  end

  describe '.service_desk_counts' do
    subject { described_class.send(:service_desk_counts) }

    let(:project) { create(:project, :service_desk_enabled) }

    it 'gathers Service Desk data' do
      create_list(:issue, 2, :confidential, author: User.support_bot, project: project)

      expect(subject).to eq(service_desk_enabled_projects: 1,
                            service_desk_issues: 2)
    end
  end

  describe '.snowplow_event_counts' do
    context 'when self-monitoring project exists' do
      let_it_be(:project) { create(:project) }

      before do
        stub_application_setting(self_monitoring_project: project)
      end

      context 'and product_analytics FF is enabled for it' do
        before do
          stub_feature_flags(product_analytics: project)

          create(:product_analytics_event, project: project, se_category: 'epics', se_action: 'promote')
          create(:product_analytics_event, project: project, se_category: 'epics', se_action: 'promote', collector_tstamp: 28.days.ago)
        end

        it 'returns promoted_issues for the time period' do
          expect(described_class.snowplow_event_counts[:promoted_issues]).to eq(2)
          expect(described_class.snowplow_event_counts(
            time_period: described_class.last_28_days_time_period(column: :collector_tstamp)
          )[:promoted_issues]).to eq(1)
        end
      end

      context 'and product_analytics FF is disabled' do
        before do
          stub_feature_flags(product_analytics: false)
        end

        it 'returns an empty hash' do
          expect(described_class.snowplow_event_counts).to eq({})
        end
      end
    end

    context 'when self-monitoring project does not exist' do
      it 'returns an empty hash' do
        expect(described_class.snowplow_event_counts).to eq({})
      end
    end
  end
end