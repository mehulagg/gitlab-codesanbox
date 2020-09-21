# frozen_string_literal: true

module API
  class ProjectImport < Grape::API::Instance
    include PaginationParams

    MAXIMUM_FILE_SIZE = 50.megabytes

    helpers Helpers::ProjectsHelpers
    helpers Helpers::FileUploadHelpers
    helpers Helpers::RateLimiter

    helpers do
      def import_params
        declared_params(include_missing: false)
      end
    end

    before do
      forbidden! unless Gitlab::CurrentSettings.import_sources.include?('gitlab_project')
    end

    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Workhorse authorize the project import upload' do
        detail 'This feature was introduced in GitLab 12.9'
      end
      post 'import/authorize' do
        require_gitlab_workhorse!

        status 200
        content_type Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE

        ImportExportUploader.workhorse_authorize(
          has_length: false,
          maximum_size: Gitlab::CurrentSettings.max_import_size.megabytes
        )
      end

      params do
        requires :path, type: String, desc: 'The new project path and name'
        requires :file, type: ::API::Validations::Types::WorkhorseFile, desc: 'The project export file to be imported'
        optional :name, type: String, desc: 'The name of the project to be imported. Defaults to the path of the project if not provided.'
        optional :namespace, type: String, desc: "The ID or name of the namespace that the project will be imported into. Defaults to the current user's namespace."
        optional :overwrite, type: Boolean, default: false, desc: 'If there is a project in the same namespace and with the same name overwrite it'
        optional :override_params,
                 type: Hash,
                 desc: 'New project params to override values in the export' do
          use :optional_project_params
        end
        optional 'file.path', type: String, desc: 'Path to locally stored body (generated by Workhorse)'
        optional 'file.name', type: String, desc: 'Real filename as send in Content-Disposition (generated by Workhorse)'
        optional 'file.type', type: String, desc: 'Real content type as send in Content-Type (generated by Workhorse)'
        optional 'file.size', type: Integer, desc: 'Real size of file (generated by Workhorse)'
        optional 'file.md5', type: String, desc: 'MD5 checksum of the file (generated by Workhorse)'
        optional 'file.sha1', type: String, desc: 'SHA1 checksum of the file (generated by Workhorse)'
        optional 'file.sha256', type: String, desc: 'SHA256 checksum of the file (generated by Workhorse)'
        optional 'file.etag', type: String, desc: 'Etag of the file (generated by Workhorse)'
        optional 'file.remote_id', type: String, desc: 'Remote_id of the file (generated by Workhorse)'
        optional 'file.remote_url', type: String, desc: 'Remote_url of the file (generated by Workhorse)'
      end
      desc 'Create a new project import' do
        detail 'This feature was introduced in GitLab 10.6.'
        success Entities::ProjectImportStatus
      end
      post 'import' do
        require_gitlab_workhorse!

        check_rate_limit! :project_import, [current_user, :project_import]

        Gitlab::QueryLimiting.whitelist('https://gitlab.com/gitlab-org/gitlab-foss/issues/42437')

        validate_file!

        namespace = if import_params[:namespace]
                      find_namespace!(import_params[:namespace])
                    else
                      current_user.namespace
                    end

        project_params = {
            path: import_params[:path],
            namespace_id: namespace.id,
            name: import_params[:name],
            file: import_params[:file],
            overwrite: import_params[:overwrite]
        }

        override_params = import_params.delete(:override_params)
        filter_attributes_using_license!(override_params) if override_params

        project = ::Projects::GitlabProjectsImportService.new(
          current_user, project_params, override_params
        ).execute

        render_api_error!(project.errors.full_messages&.first, 400) unless project.saved?

        present project, with: Entities::ProjectImportStatus
      end

      params do
        requires :id, type: String, desc: 'The ID of a project'
      end
      desc 'Get a project export status' do
        detail 'This feature was introduced in GitLab 10.6.'
        success Entities::ProjectImportStatus
      end
      get ':id/import' do
        present user_project, with: Entities::ProjectImportStatus
      end
    end
  end
end