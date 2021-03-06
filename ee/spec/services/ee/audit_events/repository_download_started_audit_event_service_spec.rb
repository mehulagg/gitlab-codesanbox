# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::AuditEvents::RepositoryDownloadStartedAuditEventService do
  describe '#security_event' do
    include_examples 'logs the custom audit event' do
      let(:user) { create(:user) }
      let(:ip_address) { '127.0.0.1' }
      let(:entity) { create(:project) }
      let(:entity_type) { 'Project' }
      let(:custom_message) { 'Repository Download Started' }
      let(:service) { described_class.new(user, entity, ip_address) }
    end
  end
end
