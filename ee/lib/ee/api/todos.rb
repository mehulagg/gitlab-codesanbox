# frozen_string_literal: true

module EE
  module API
    module Todos
      extend ActiveSupport::Concern

      prepended do
        helpers do
          extend ::Gitlab::Utils::Override

          def authorize_can_read!
            authorize!(:read_epic, user_group)
          end
        end

        resource :groups, requirements: ::API::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
          desc 'Create a todo on an epic' do
            success ::API::Entities::Todo
          end
          params do
            requires :epic_iid, type: Integer, desc: 'The IID of an epic'
          end
          post ":id/epics/:epic_iid/todo" do
            authorize_can_read!
            epic = find_group_epic(params[:epic_iid])
            todo = ::TodoService.new.mark_todo(epic, current_user).first

            if todo
              present todo, with: ::API::Entities::Todo, current_user: current_user
            else
              not_modified!
            end
          end
        end
      end
    end
  end
end
