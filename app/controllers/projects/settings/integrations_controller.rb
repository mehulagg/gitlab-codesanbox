# frozen_string_literal: true

module Projects
  module Settings
    class IntegrationsController < Projects::ApplicationController
      before_action :authorize_admin_project!
      layout "project_settings"

      def show
        @services = @project.find_or_initialize_services
      end
    end
  end
end
