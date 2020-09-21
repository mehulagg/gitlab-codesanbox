# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Integration do
  let!(:project_1) { create(:project) }
  let!(:project_2) { create(:project) }
  let!(:project_3) { create(:project) }
  let(:instance_integration) { create(:jira_service, :instance) }

  before do
    create(:jira_service, project: project_1, inherit_from_id: instance_integration.id)
    create(:jira_service, project: project_2, inherit_from_id: nil)
    create(:slack_service, project: project_1, inherit_from_id: nil)
  end

  describe '#with_custom_integration_for' do
    it 'returns projects with custom integrations' do
      expect(Project.with_custom_integration_for(instance_integration)).to contain_exactly(project_2)
    end
  end

  describe '#ids_without_integration' do
    it 'returns projects ids without an integration' do
      expect(Project.ids_without_integration(instance_integration, 100)).to contain_exactly(project_3.id)
    end
  end
end
