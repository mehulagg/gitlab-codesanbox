# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting group information' do
  include GraphqlHelpers

  let(:user) { create(:user) }

  describe "Query group(fullPath)" do
    def group_query(group)
      graphql_query_for('group', 'fullPath' => group.full_path)
    end

    context 'when Group SSO is enforced' do
      let(:group) { create(:group, :private) }

      before do
        stub_licensed_features(group_saml: true)
        saml_provider = create(:saml_provider, enforced_sso: true, group: group)
        create(:group_saml_identity, saml_provider: saml_provider, user: user)
        group.add_guest(user)
      end

      it 'returns null data when not authorized' do
        post_graphql(group_query(group))

        expect(graphql_data['group']).to be_nil
      end

      it 'allows access via session' do
        post_graphql(group_query(group), current_user: user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(graphql_data['group']['id']).to eq(group.to_global_id.to_s)
      end

      it 'allows access via bearer token' do
        token = create(:personal_access_token, user: user).token
        post_graphql(group_query(group), headers: { 'Authorization' => "Bearer #{token}" })

        expect(response).to have_gitlab_http_status(:ok)
        expect(graphql_data['group']['id']).to eq(group.to_global_id.to_s)
      end
    end

    context 'when loading vulnerabilityGrades alongside with Vulnerability.userNotesCount' do
      let_it_be(:private_group) { create(:group, :private) }
      let_it_be(:public_group) { create(:group, :public) }

      let(:fields_public_group) do
        <<~QUERY
        vulnerabilityGrades {
          grade
          count
          projects {
            nodes {
              vulnerabilities {
                nodes {
                  id
                  userNotesCount
                }
              }
            }
          }
        }
        QUERY
      end

      let(:fields_private_group) do
        <<~QUERY
        vulnerabilityGrades {
          grade
          count
          projects {
            nodes {
              confirmedVulnerabilities: vulnerabilities(state: CONFIRMED) {
                nodes {
                  id
                  userNotesCount
                }
              }
              dismissedVulnerabilities: vulnerabilities(state: DISMISSED) {
                nodes {
                  id
                  userNotesCount
                }
              }
            }
          }
        }
        QUERY
      end

      let(:queries) do
        [
          { query: graphql_query_for('group', { 'fullPath' => private_group.full_path }, fields_private_group) },
          { query: graphql_query_for('group', { 'fullPath' => public_group.full_path }, fields_public_group) }
        ]
      end

      let_it_be(:public_project) { create(:project, group: public_group) }
      let_it_be(:private_project) { create(:project, group: private_group) }

      let_it_be(:vulnerability_1) { create(:vulnerability, :dismissed, :critical_severity, :with_notes, notes_count: 2, project: public_project) }
      let_it_be(:vulnerability_2) { create(:vulnerability, :confirmed, :high_severity, :with_notes, notes_count: 3, project: public_project) }
      let_it_be(:vulnerability_3) { create(:vulnerability, :dismissed, :medium_severity, :with_notes, notes_count: 4, project: private_project) }
      let_it_be(:vulnerability_4) { create(:vulnerability, :confirmed, :low_severity, :with_notes, notes_count: 7, project: private_project) }

      let_it_be(:vulnerability_statistic_1) { create(:vulnerability_statistic, :grade_c, project: public_project) }
      let_it_be(:vulnerability_statistic_2) { create(:vulnerability_statistic, :grade_d, project: private_project) }

      let(:first_graphql_data) do
        json_response.first['data']
      end

      let(:second_graphql_data) do
        json_response.last['data']
      end

      let(:expected_private_group_response) do
        [
          {
            'count' => 1,
            'grade' => 'D',
            'projects' => {
              'nodes' => [
                {
                  'confirmedVulnerabilities' => {
                    'nodes' => [
                      { 'id' => vulnerability_4.to_global_id.to_s, 'userNotesCount' => 7 }
                    ]
                  },
                  'dismissedVulnerabilities' => {
                    'nodes' => [
                      { 'id' => vulnerability_3.to_global_id.to_s, 'userNotesCount' => 4 }
                    ]
                  }
                }
              ]
            }
          },
          {
            'count' => 0,
            'grade' => 'C',
            'projects' => {
              'nodes' => []
            }
          }
        ]
      end

      let(:expected_public_group_response) do
        [
          {
            'count' => 0,
            'grade' => 'D',
            'projects' => {
              'nodes' => []
            }
          },
          {
            'count' => 1,
            'grade' => 'C',
            'projects' => {
              'nodes' => [
                {
                  'vulnerabilities' => {
                    'nodes' => [
                      { 'id' => vulnerability_1.to_global_id.to_s, 'userNotesCount' => 2 },
                      { 'id' => vulnerability_2.to_global_id.to_s, 'userNotesCount' => 3 }
                    ]
                  }
                }
              ]
            }
          }
        ]
      end

      before do
        public_group.add_developer(user)
        private_group.add_developer(user)
        stub_licensed_features(security_dashboard: true)

        post_multiplex(queries, current_user: user)
      end

      it 'finds vulnerability grades for only projects that were added to instance security dashboard', :aggregate_failures do
        expect(first_graphql_data.dig('group', 'vulnerabilityGrades')).to match_array(expected_private_group_response)
        expect(second_graphql_data.dig('group', 'vulnerabilityGrades')).to match_array(expected_public_group_response)
      end

      it 'returns a successful response', :aggregate_failures do
        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors).to eq([nil, nil])
      end
    end
  end
end
