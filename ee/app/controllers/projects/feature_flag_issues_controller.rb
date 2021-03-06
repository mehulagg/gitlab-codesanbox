# frozen_string_literal: true

module Projects
  class FeatureFlagIssuesController < Projects::ApplicationController
    include IssuableLinks

    before_action :ensure_feature_enabled!
    before_action :authorize_admin_feature_flags_issue_links!

    private

    def create_service
      ::FeatureFlagIssues::CreateService.new(feature_flag, current_user, create_params)
    end

    def list_service
      ::FeatureFlagIssues::ListService.new(feature_flag, current_user)
    end

    def destroy_service
      ::FeatureFlagIssues::DestroyService.new(link, current_user)
    end

    def link
      @link ||= ::FeatureFlagIssue.find(params[:id])
    end

    def feature_flag
      project.operations_feature_flags.find_by_iid(params[:feature_flag_iid])
    end

    def ensure_feature_enabled!
      render_404 unless Feature.enabled?(:feature_flags_issue_links, project, default_enabled: true)
    end
  end
end
