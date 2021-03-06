# frozen_string_literal: true

module Projects::Security::SastConfigurationHelper
  def sast_configuration_data(project)
    {
      create_sast_merge_request_path: project_security_configuration_sast_path(project),
      project_path: project.full_path,
      sast_documentation_path: help_page_path('user/application_security/sast/index', anchor: 'configuration'),
      security_configuration_path: project_security_configuration_path(project)
    }
  end
end
