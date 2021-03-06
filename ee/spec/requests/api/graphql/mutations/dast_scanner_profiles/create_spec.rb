# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Creating a DAST Scanner Profile' do
  include GraphqlHelpers

  let(:profile_name) { FFaker::Company.catch_phrase }
  let(:dast_scanner_profile) { DastScannerProfile.find_by(project: project, name: profile_name) }

  let(:mutation_name) { :dast_scanner_profile_create }
  let(:mutation) do
    graphql_mutation(
      mutation_name,
      full_path: full_path,
      profile_name: profile_name
    )
  end

  it_behaves_like 'an on-demand scan mutation when user cannot run an on-demand scan'
  it_behaves_like 'an on-demand scan mutation when user can run an on-demand scan' do
    it 'returns the dast_scanner_profile id' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(mutation_response['id']).to eq(dast_scanner_profile.to_global_id.to_s)
    end

    it 'returns the dast_scanner_profile global_id' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(mutation_response['globalId']).to eq(dast_scanner_profile.to_global_id.to_s)
    end

    context 'when dast_scanner_profile exists' do
      before do
        DastScannerProfile.create!(project: project, name: profile_name)
      end

      it 'returns errors' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(mutation_response['errors']).to include('Name has already been taken')
      end
    end
  end
end
