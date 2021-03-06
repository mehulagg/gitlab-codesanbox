# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupPolicy do
  include_context 'GroupPolicy context'

  context 'when epics feature is disabled' do
    let(:current_user) { owner }

    it { is_expected.to be_disallowed(:read_epic, :create_epic, :admin_epic, :destroy_epic, :read_confidential_epic, :destroy_epic_link) }
  end

  context 'when epics feature is enabled' do
    before do
      stub_licensed_features(epics: true)
    end

    context 'when user is owner' do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(:read_epic, :create_epic, :admin_epic, :destroy_epic, :read_confidential_epic, :destroy_epic_link) }
    end

    context 'when user is maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:read_epic, :create_epic, :admin_epic, :read_confidential_epic, :destroy_epic_link) }
      it { is_expected.to be_disallowed(:destroy_epic) }
    end

    context 'when user is developer' do
      let(:current_user) { developer }

      it { is_expected.to be_allowed(:read_epic, :create_epic, :admin_epic, :read_confidential_epic, :destroy_epic_link) }
      it { is_expected.to be_disallowed(:destroy_epic) }
    end

    context 'when user is reporter' do
      let(:current_user) { reporter }

      it { is_expected.to be_allowed(:read_epic, :create_epic, :admin_epic, :read_confidential_epic, :destroy_epic_link) }
      it { is_expected.to be_disallowed(:destroy_epic) }
    end

    context 'when user is guest' do
      let(:current_user) { guest }

      it { is_expected.to be_allowed(:read_epic) }
      it { is_expected.to be_disallowed(:create_epic, :admin_epic, :destroy_epic, :read_confidential_epic, :destroy_epic_link) }
    end

    context 'when user is not member' do
      let(:current_user) { create(:user) }

      it { is_expected.to be_disallowed(:read_epic, :create_epic, :admin_epic, :destroy_epic, :read_confidential_epic, :destroy_epic_link) }
    end

    context 'when user is anonymous' do
      let(:current_user) { nil }

      it { is_expected.to be_disallowed(:read_epic, :create_epic, :admin_epic, :destroy_epic, :read_confidential_epic, :destroy_epic_link) }
    end
  end

  context 'when iterations feature is disabled' do
    let(:current_user) { owner }

    before do
      stub_licensed_features(iterations: false)
    end

    it { is_expected.to be_disallowed(:read_iteration, :create_iteration, :admin_iteration) }
  end

  context 'when iterations feature is enabled' do
    before do
      stub_licensed_features(iterations: true)
    end

    context 'when user is a developer' do
      let(:current_user) { developer }

      it { is_expected.to be_allowed(:read_iteration, :create_iteration, :admin_iteration) }
    end

    context 'when user is a guest' do
      let(:current_user) { guest }

      it { is_expected.to be_allowed(:read_iteration) }
      it { is_expected.to be_disallowed(:create_iteration, :admin_iteration) }
    end

    context 'when user is logged out' do
      let(:current_user) { nil }

      it { is_expected.to be_disallowed(:read_iteration, :create_iteration, :admin_iteration) }
    end

    context 'when project is private' do
      let(:group) { create(:group, :public, :owner_subgroup_creation_only) }

      context 'when user is logged out' do
        let(:current_user) { nil }

        it { is_expected.to be_allowed(:read_iteration) }
        it { is_expected.to be_disallowed(:create_iteration, :admin_iteration) }
      end
    end
  end

  context 'when cluster deployments is available' do
    let(:current_user) { maintainer }

    before do
      stub_licensed_features(cluster_deployments: true)
    end

    it { is_expected.to be_allowed(:read_cluster_environments) }
  end

  context 'when cluster deployments is not available' do
    let(:current_user) { maintainer }

    before do
      stub_licensed_features(cluster_deployments: false)
    end

    it { is_expected.not_to be_allowed(:read_cluster_environments) }
  end

  context 'when contribution analytics is available' do
    let(:current_user) { developer }

    before do
      stub_licensed_features(contribution_analytics: true)
    end

    context 'when signed in user is a member of the group' do
      it { is_expected.to be_allowed(:read_group_contribution_analytics) }
    end

    describe 'when user is not a member of the group' do
      let(:current_user) { non_group_member }
      let(:private_group) { create(:group, :private) }

      subject { described_class.new(non_group_member, private_group) }

      context 'when user is not invited to any of the group projects' do
        it { is_expected.not_to be_allowed(:read_group_contribution_analytics) }
      end

      context 'when user is invited to a group project, but not to the group' do
        let(:private_project) { create(:project, :private, group: private_group) }

        before do
          private_project.add_guest(non_group_member)
        end

        it { is_expected.not_to be_allowed(:read_group_contribution_analytics) }
      end
    end
  end

  context 'when contribution analytics is not available' do
    let(:current_user) { developer }

    before do
      stub_licensed_features(contribution_analytics: false)
    end

    it { is_expected.not_to be_allowed(:read_group_contribution_analytics) }
  end

  context 'when group activity analytics is available' do
    let(:current_user) { developer }

    before do
      stub_feature_flags(group_activity_analytics: true)
      stub_licensed_features(group_activity_analytics: true)
    end

    it { is_expected.to be_allowed(:read_group_activity_analytics) }
  end

  context 'when group activity analytics is not available' do
    let(:current_user) { developer }

    before do
      stub_feature_flags(group_activity_analytics: false)
      stub_licensed_features(group_activity_analytics: false)
    end

    it { is_expected.not_to be_allowed(:read_group_activity_analytics) }
  end

  context 'when group repository analytics is available' do
    let(:current_user) { guest }

    before do
      stub_licensed_features(group_repository_analytics: true)
    end

    it { is_expected.to be_allowed(:read_group_repository_analytics) }
  end

  context 'when group repository analytics is not available' do
    let(:current_user) { guest }

    before do
      stub_licensed_features(group_repository_analytics: false)
    end

    it { is_expected.not_to be_allowed(:read_group_repository_analytics) }
  end

  context 'when timelogs report feature is enabled' do
    before do
      stub_licensed_features(group_timelogs: true)
    end

    context 'admin' do
      let(:current_user) { admin }

      it { is_expected.to be_allowed(:read_group_timelogs) }
    end

    context 'with owner' do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(:read_group_timelogs) }
    end

    context 'with maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:read_group_timelogs) }
    end

    context 'with reporter' do
      let(:current_user) { reporter }

      it { is_expected.to be_allowed(:read_group_timelogs) }
    end

    context 'with guest' do
      let(:current_user) { guest }

      it { is_expected.to be_disallowed(:read_group_timelogs) }
    end

    context 'with non member' do
      let(:current_user) { create(:user) }

      it { is_expected.to be_disallowed(:read_group_timelogs) }
    end

    context 'with anonymous' do
      let(:current_user) { nil }

      it { is_expected.to be_disallowed(:read_group_timelogs) }
    end
  end

  context 'when timelogs report feature is disabled' do
    let(:current_user) { admin }

    before do
      stub_licensed_features(group_timelogs: false)
    end

    it { is_expected.to be_disallowed(:read_group_timelogs) }
  end

  describe 'per group SAML' do
    let(:current_user) { maintainer }

    it { is_expected.to be_disallowed(:admin_group_saml) }

    context 'owner' do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(:admin_group_saml) }
    end

    context 'admin' do
      let(:current_user) { admin }

      it { is_expected.to be_allowed(:admin_group_saml) }
    end

    context 'with sso enforcement enabled' do
      let(:current_user) { guest }

      let_it_be(:saml_provider) { create(:saml_provider, group: group, enforced_sso: true) }

      before do
        stub_licensed_features(group_saml: true)
      end

      context 'when the session has been set globally' do
        around do |example|
          Gitlab::Session.with_session({}) do
            example.run
          end
        end

        it 'prevents access without a SAML session' do
          is_expected.not_to be_allowed(:read_group)
        end

        context 'as a group owner' do
          before do
            group.add_owner(current_user)
          end

          it 'prevents access without a SAML session' do
            is_expected.not_to allow_action(:read_group)
          end
        end

        it 'allows access with a SAML session' do
          Gitlab::Auth::GroupSaml::SsoEnforcer.new(saml_provider).update_session

          is_expected.to be_allowed(:read_group)
        end
      end

      context 'when there is no global session or sso state' do
        it "allows access because we haven't yet restricted all use cases" do
          is_expected.to be_allowed(:read_group)
        end
      end
    end
  end

  context 'with ip restriction' do
    let(:current_user) { developer }

    before do
      allow(Gitlab::IpAddressState).to receive(:current).and_return('192.168.0.2')
      stub_licensed_features(group_ip_restriction: true)
    end

    context 'without restriction' do
      it { is_expected.to be_allowed(:read_group) }
    end

    context 'with restriction' do
      before do
        create(:ip_restriction, group: group, range: range)
      end

      context 'address is within the range' do
        let(:range) { '192.168.0.0/24' }

        it { is_expected.to be_allowed(:read_group) }
      end

      context 'address is outside the range' do
        let(:range) { '10.0.0.0/8' }

        context 'as developer' do
          it { is_expected.to be_disallowed(:read_group) }
        end

        context 'as owner' do
          let(:current_user) { owner }

          it { is_expected.to be_allowed(:read_group) }
        end
      end
    end
  end

  context 'when LDAP sync is not enabled' do
    context 'owner' do
      let(:current_user) { owner }

      it { is_expected.to be_disallowed(:override_group_member) }
      it { is_expected.to be_allowed(:admin_ldap_group_links) }
      it { is_expected.to be_allowed(:admin_ldap_group_settings) }

      context 'does not allow group owners to manage ldap' do
        before do
          stub_application_setting(allow_group_owners_to_manage_ldap: false)
        end

        it { is_expected.to be_disallowed(:admin_ldap_group_links) }
        it { is_expected.to be_disallowed(:admin_ldap_group_settings) }
      end
    end

    context 'admin' do
      let(:current_user) { admin }

      it { is_expected.to be_disallowed(:override_group_member) }
      it { is_expected.to be_allowed(:admin_ldap_group_links) }
      it { is_expected.to be_allowed(:admin_ldap_group_settings) }
    end
  end

  context 'when LDAP sync is enabled' do
    before do
      allow(group).to receive(:ldap_synced?).and_return(true)
    end

    context 'with no user' do
      let(:current_user) { nil }

      it { is_expected.to be_disallowed(:override_group_member) }
      it { is_expected.to be_disallowed(:admin_ldap_group_links) }
      it { is_expected.to be_disallowed(:admin_ldap_group_settings) }
    end

    context 'guests' do
      let(:current_user) { guest }

      it { is_expected.to be_disallowed(:override_group_member) }
      it { is_expected.to be_disallowed(:admin_ldap_group_links) }
      it { is_expected.to be_disallowed(:admin_ldap_group_settings) }
    end

    context 'reporter' do
      let(:current_user) { reporter }

      it { is_expected.to be_disallowed(:override_group_member) }
      it { is_expected.to be_disallowed(:admin_ldap_group_links) }
      it { is_expected.to be_disallowed(:admin_ldap_group_settings) }
    end

    context 'developer' do
      let(:current_user) { developer }

      it { is_expected.to be_disallowed(:override_group_member) }
      it { is_expected.to be_disallowed(:admin_ldap_group_links) }
      it { is_expected.to be_disallowed(:admin_ldap_group_settings) }
    end

    context 'maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_disallowed(:override_group_member) }
      it { is_expected.to be_disallowed(:admin_ldap_group_links) }
      it { is_expected.to be_disallowed(:admin_ldap_group_settings) }
    end

    context 'owner' do
      let(:current_user) { owner }

      context 'allow group owners to manage ldap' do
        it { is_expected.to be_allowed(:override_group_member) }
      end

      context 'does not allow group owners to manage ldap' do
        before do
          stub_application_setting(allow_group_owners_to_manage_ldap: false)
        end

        it { is_expected.to be_disallowed(:override_group_member) }
        it { is_expected.to be_disallowed(:admin_ldap_group_links) }
        it { is_expected.to be_disallowed(:admin_ldap_group_settings) }
      end
    end

    context 'admin' do
      let(:current_user) { admin }

      it { is_expected.to be_allowed(:override_group_member) }
      it { is_expected.to be_allowed(:admin_ldap_group_links) }
      it { is_expected.to be_allowed(:admin_ldap_group_settings) }
    end

    context 'when memberships locked to LDAP' do
      before do
        stub_application_setting(allow_group_owners_to_manage_ldap: true)
        stub_application_setting(lock_memberships_to_ldap: true)
      end

      context 'admin' do
        let(:current_user) { admin }

        context 'when admin mode enabled', :enable_admin_mode do
          it { is_expected.to be_allowed(:override_group_member) }
          it { is_expected.to be_allowed(:update_group_member) }
        end

        context 'when admin mode disabled' do
          it { is_expected.to be_disallowed(:override_group_member) }
          it { is_expected.to be_disallowed(:update_group_member) }
        end
      end

      context 'owner' do
        let(:current_user) { owner }

        it { is_expected.not_to be_allowed(:admin_group_member) }
        it { is_expected.not_to be_allowed(:override_group_member) }
        it { is_expected.not_to be_allowed(:update_group_member) }
      end

      context 'when LDAP sync is enabled' do
        let(:current_user) { owner }

        before do
          allow(group).to receive(:ldap_synced?).and_return(true)
        end

        context 'Group Owner disable membership lock' do
          before do
            group.update!(unlock_membership_to_ldap: true)
            stub_feature_flags(ldap_settings_unlock_groups_by_owners: true)
          end

          it { is_expected.to be_allowed(:admin_group_member) }
          it { is_expected.to be_allowed(:override_group_member) }
          it { is_expected.to be_allowed(:update_group_member) }

          context 'ldap_settings_unlock_groups_by_owners is disabled' do
            before do
              stub_feature_flags(ldap_settings_unlock_groups_by_owners: false)
            end

            it { is_expected.to be_disallowed(:admin_group_member) }
            it { is_expected.to be_disallowed(:override_group_member) }
            it { is_expected.to be_disallowed(:update_group_member) }
          end
        end

        context 'Group Owner keeps the membership lock' do
          before do
            group.update!(unlock_membership_to_ldap: false)
          end

          it { is_expected.not_to be_allowed(:admin_group_member) }
          it { is_expected.not_to be_allowed(:override_group_member) }
          it { is_expected.not_to be_allowed(:update_group_member) }
        end
      end

      context 'when LDAP sync is disable' do
        let(:current_user) { owner }

        it { is_expected.not_to be_allowed(:admin_group_member) }
        it { is_expected.not_to be_allowed(:override_group_member) }
        it { is_expected.not_to be_allowed(:update_group_member) }
      end
    end
  end

  describe 'read_group_credentials_inventory' do
    context 'with admin' do
      let(:current_user) { admin }

      it { is_expected.to be_allowed(:read_group_credentials_inventory) }
    end

    context 'with owner' do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(:read_group_credentials_inventory) }
    end

    context 'with maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_disallowed(:read_group_credentials_inventory) }
    end

    context 'with developer' do
      let(:current_user) { developer }

      it { is_expected.to be_disallowed(:read_group_credentials_inventory) }

      context 'when security dashboard features is not available' do
        before do
          stub_licensed_features(security_dashboard: false)
        end

        it { is_expected.to be_disallowed(:read_group_credentials_inventory) }
      end
    end

    context 'with reporter' do
      let(:current_user) { reporter }

      it { is_expected.to be_disallowed(:read_group_credentials_inventory) }
    end

    context 'with guest' do
      let(:current_user) { guest }

      it { is_expected.to be_disallowed(:read_group_credentials_inventory) }
    end

    context 'with non member' do
      let(:current_user) { create(:user) }

      it { is_expected.to be_disallowed(:read_group_credentials_inventory) }
    end

    context 'with anonymous' do
      let(:current_user) { nil }

      it { is_expected.to be_disallowed(:read_group_credentials_inventory) }
    end
  end

  describe 'change_prevent_group_forking' do
    context 'when feature is disabled' do
      context 'with owner' do
        let(:current_user) { owner }

        it { is_expected.to be_disallowed(:change_prevent_group_forking) }
      end

      context 'with maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_disallowed(:change_prevent_group_forking) }
      end
    end

    context 'when feature is enabled' do
      before do
        stub_licensed_features(group_forking_protection: true)
      end

      context 'with owner' do
        let(:current_user) { owner }

        it { is_expected.to be_allowed(:change_prevent_group_forking) }

        context 'when group has parent' do
          let(:group) { create(:group, :private, parent: create(:group)) }

          it { is_expected.to be_disallowed(:change_prevent_group_forking) }
        end
      end

      context 'with maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_disallowed(:change_prevent_group_forking) }
      end
    end
  end

  describe 'read_group_security_dashboard & create_vulnerability_export' do
    let(:abilities) { %i(read_group_security_dashboard create_vulnerability_export) }

    before do
      stub_licensed_features(security_dashboard: true)
    end

    context 'with admin' do
      let(:current_user) { admin }

      it { is_expected.to be_allowed(*abilities) }
    end

    context 'with owner' do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(*abilities) }
    end

    context 'with maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(*abilities) }
    end

    context 'with developer' do
      let(:current_user) { developer }

      it { is_expected.to be_allowed(*abilities) }

      context 'when security dashboard features is not available' do
        before do
          stub_licensed_features(security_dashboard: false)
        end

        it { is_expected.to be_disallowed(*abilities) }
      end
    end

    context 'with reporter' do
      let(:current_user) { reporter }

      it { is_expected.to be_disallowed(*abilities) }
    end

    context 'with guest' do
      let(:current_user) { guest }

      it { is_expected.to be_disallowed(*abilities) }
    end

    context 'with non member' do
      let(:current_user) { create(:user) }

      it { is_expected.to be_disallowed(*abilities) }
    end

    context 'with anonymous' do
      let(:current_user) { nil }

      it { is_expected.to be_disallowed(*abilities) }
    end
  end

  describe 'private nested group use the highest access level from the group and inherited permissions' do
    let(:nested_group) { create(:group, :private, parent: group) }

    before do
      nested_group.add_guest(guest)
      nested_group.add_guest(reporter)
      nested_group.add_guest(developer)
      nested_group.add_guest(maintainer)

      group.owners.destroy_all # rubocop: disable Cop/DestroyAll

      group.add_guest(owner)
      nested_group.add_owner(owner)
    end

    subject { described_class.new(current_user, nested_group) }

    context 'auditor' do
      let(:current_user) { create(:user, :auditor) }

      before do
        stub_licensed_features(security_dashboard: true)
      end

      specify do
        expect_allowed(:read_group)
        expect_allowed(:read_group_security_dashboard)
        expect_disallowed(:upload_file)
        expect_disallowed(*reporter_permissions)
        expect_disallowed(*developer_permissions)
        expect_disallowed(*maintainer_permissions)
        expect_disallowed(*owner_permissions)
      end
    end
  end

  context 'commit_committer_check is not enabled by the current license' do
    before do
      stub_licensed_features(commit_committer_check: false)
    end

    let(:current_user) { maintainer }

    it { is_expected.not_to be_allowed(:change_commit_committer_check) }
    it { is_expected.not_to be_allowed(:read_commit_committer_check) }
  end

  context 'commit_committer_check is enabled by the current license' do
    before do
      stub_licensed_features(commit_committer_check: true)
    end

    context 'the user is a maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:change_commit_committer_check) }
      it { is_expected.to be_allowed(:read_commit_committer_check) }
    end

    context 'the user is a developer' do
      let(:current_user) { developer }

      it { is_expected.not_to be_allowed(:change_commit_committer_check) }
      it { is_expected.to be_allowed(:read_commit_committer_check) }
    end

    context 'it is enabled on global level' do
      before do
        create(:push_rule_sample, commit_committer_check: true)
      end

      context 'the user is a maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.not_to be_allowed(:change_commit_committer_check) }
        it { is_expected.to be_allowed(:read_commit_committer_check) }
      end

      context 'the user is a developer' do
        let(:current_user) { developer }

        it { is_expected.not_to be_allowed(:change_commit_committer_check) }
        it { is_expected.to be_allowed(:read_commit_committer_check) }
      end
    end
  end

  context 'reject_unsigned_commits is not enabled by the current license' do
    before do
      stub_licensed_features(reject_unsigned_commits: false)
    end

    let(:current_user) { maintainer }

    it { is_expected.not_to be_allowed(:change_reject_unsigned_commits) }
    it { is_expected.not_to be_allowed(:read_reject_unsigned_commits) }
  end

  context 'reject_unsigned_commits is enabled by the current license' do
    before do
      stub_licensed_features(reject_unsigned_commits: true)
    end

    context 'the user is a maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:change_reject_unsigned_commits) }
      it { is_expected.to be_allowed(:read_reject_unsigned_commits) }
    end

    context 'the user is a developer' do
      let(:current_user) { developer }

      it { is_expected.not_to be_allowed(:change_reject_unsigned_commits) }
      it { is_expected.to be_allowed(:read_reject_unsigned_commits) }
    end

    context 'it is enabled on global level' do
      before do
        create(:push_rule_sample, reject_unsigned_commits: true)
      end

      context 'the user is a maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.not_to be_allowed(:change_reject_unsigned_commits) }
        it { is_expected.to be_allowed(:read_reject_unsigned_commits) }
      end

      context 'the user is a developer' do
        let(:current_user) { developer }

        it { is_expected.not_to be_allowed(:change_reject_unsigned_commits) }
        it { is_expected.to be_allowed(:read_reject_unsigned_commits) }
      end

      context 'the user is an admin', :enable_admin_mode do
        let(:current_user) { admin }

        it { is_expected.to be_allowed(:change_reject_unsigned_commits) }
        it { is_expected.to be_allowed(:read_reject_unsigned_commits) }
      end
    end
  end

  shared_examples 'analytics policy' do |action|
    shared_examples 'policy by role' do |role|
      context role do
        let(:current_user) { public_send(role) }

        it 'is allowed' do
          is_expected.to be_allowed(action)
        end
      end
    end

    %w[admin owner maintainer developer reporter].each do |role|
      include_examples 'policy by role', role
    end

    context 'guest' do
      let(:current_user) { guest }

      it 'is not allowed' do
        is_expected.to be_disallowed(action)
      end
    end
  end

  describe 'view_productivity_analytics' do
    include_examples 'analytics policy', :view_productivity_analytics
  end

  describe 'view_type_of_work_charts' do
    include_examples 'analytics policy', :view_type_of_work_charts
  end

  describe '#read_group_saml_identity' do
    let_it_be(:saml_provider) { create(:saml_provider, group: group, enabled: true) }

    context 'for owner' do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(:read_group_saml_identity) }

      context 'without Group SAML enabled' do
        before do
          saml_provider.update!(enabled: false)
        end

        it { is_expected.to be_disallowed(:read_group_saml_identity) }
      end
    end

    %w[maintainer developer reporter guest].each do |role|
      context "for #{role}" do
        let(:current_user) { public_send(role) }

        it { is_expected.to be_disallowed(:read_group_saml_identity) }
      end
    end
  end

  describe 'update_default_branch_protection' do
    context 'for an admin' do
      let(:current_user) { admin }

      context 'when the `default_branch_protection_restriction_in_groups` feature is available' do
        before do
          stub_licensed_features(default_branch_protection_restriction_in_groups: true)
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is enabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: true)
          end

          it { is_expected.to be_allowed(:update_default_branch_protection) }
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is disabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: false)
          end

          context 'when admin mode is enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(:update_default_branch_protection) }
          end

          context 'when admin mode is disabled' do
            it { is_expected.to be_disallowed(:update_default_branch_protection) }
          end
        end
      end

      context 'when the `default_branch_protection_restriction_in_groups` feature is not available' do
        before do
          stub_licensed_features(default_branch_protection_restriction_in_groups: false)
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is enabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: true)
          end

          it { is_expected.to be_allowed(:update_default_branch_protection) }
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is disabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: false)
          end

          it { is_expected.to be_allowed(:update_default_branch_protection) }
        end
      end
    end

    context 'for an owner' do
      let(:current_user) { owner }

      context 'when the `default_branch_protection_restriction_in_groups` feature is available' do
        before do
          stub_licensed_features(default_branch_protection_restriction_in_groups: true)
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is enabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: true)
          end

          it { is_expected.to be_allowed(:update_default_branch_protection) }
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is disabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: false)
          end

          it { is_expected.to be_disallowed(:update_default_branch_protection) }
        end
      end

      context 'when the `default_branch_protection_restriction_in_groups` feature is not available' do
        before do
          stub_licensed_features(default_branch_protection_restriction_in_groups: false)
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is enabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: true)
          end

          it { is_expected.to be_allowed(:update_default_branch_protection) }
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is disabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: false)
          end

          it { is_expected.to be_allowed(:update_default_branch_protection) }
        end
      end
    end
  end

  describe ':read_ci_minutes_quota' do
    using RSpec::Parameterized::TableSyntax

    let(:policy) { :read_ci_minutes_quota }

    where(:role, :allowed) do
      :guest      | false
      :reporter   | false
      :developer  | true
      :maintainer | true
      :owner      | true
      :admin      | true
    end

    with_them do
      let(:current_user) { public_send(role) }

      it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
    end
  end

  context 'when group is locked because storage usage limit exceeded' do
    let(:current_user) { owner }
    let(:policies) do
      %i[create_projects create_epic update_epic admin_milestone upload_file admin_label
         admin_list admin_issue admin_pipeline add_cluster create_cluster update_cluster
         admin_cluster admin_group_member create_deploy_token create_subgroup]
    end

    before do
      allow(group).to receive(:over_storage_limit?).and_return(over_storage_limit)
      stub_licensed_features(epics: true)
    end

    context 'when the group has exceeded its storage limit' do
      let(:over_storage_limit) { true }

      it { is_expected.to(be_disallowed(*policies)) }
    end

    context 'when the group has not exceeded its storage limit' do
      let(:over_storage_limit) { false }

      it { is_expected.to(be_allowed(*policies)) }
    end
  end

  it_behaves_like 'model with wiki policies' do
    include WikiHelpers

    let_it_be(:container) { create(:group_with_plan, plan: :bronze_plan) }
    let_it_be(:user) { owner }

    # We don't have feature toggles on groups yet, so we currently simulate
    # this by toggling the feature flag instead.
    def set_access_level(access_level)
      case access_level
      when ProjectFeature::ENABLED
        stub_feature_flags(group_wikis: true)
      when ProjectFeature::DISABLED
        stub_feature_flags(group_wikis: false)
      when ProjectFeature::PRIVATE
        skip('Access level private is not supported yet for group wikis, see https://gitlab.com/gitlab-org/gitlab/-/issues/208412')
      end
    end

    context 'when the feature flag is disabled on this group' do
      before do
        stub_feature_flags(group_wikis: create(:group))
      end

      it 'does not include the wiki permissions' do
        expect_disallowed(*wiki_permissions[:all])
      end
    end

    context 'when the feature is not licensed on this group' do
      before do
        allow(container).to receive(:feature_available?).with(:group_wikis).and_return(false)
      end

      it 'does not include the wiki permissions' do
        expect_disallowed(*wiki_permissions[:all])
      end
    end
  end

  it_behaves_like 'update namespace limit policy'

  include_examples 'analytics report embedding'
end
