# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User expands diff', :js do
  let(:project) { create(:project, :public, :repository) }
  let(:merge_request) { create(:merge_request, source_branch: 'expand-collapse-files', source_project: project, target_project: project) }

  before do
    visit(diffs_project_merge_request_path(project, merge_request))

    wait_for_requests
  end

  it 'allows user to expand diff' do
    page.within find('[id="19763941ab80e8c09871c0a425f0560d9053bcb3"]') do
      find('[data-testid="expandButton"]').click

      wait_for_requests

      expect(page).not_to have_content('Expand File')
      expect(page).to have_selector('.code')
    end
  end
end
