# frozen_string_literal: true

module Gitlab
  module Com
    ALLOWED_USER_IDS_KEY = 'gitlab_com_group_allowed_user_ids'
    EXPIRY_TIME_L1_CACHE = 1.minute
    EXPIRY_TIME_L2_CACHE = 5.minutes
    GITLAB_COM_GROUP = 'gitlab-com'

    def self.gitlab_com_group_member_id?(user_id = nil)
      return false unless Gitlab.com? && user_id && ::Feature.enabled?(:gitlab_employee_badge)

      gitlab_com_user_ids.include?(user_id)
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def self.gitlab_com_user_ids
      l1_cache_backend.fetch(ALLOWED_USER_IDS_KEY, expires_in: EXPIRY_TIME_L1_CACHE) do
        l2_cache_backend.fetch(ALLOWED_USER_IDS_KEY, expires_in: EXPIRY_TIME_L2_CACHE) do
          group = Group.find_by_name(GITLAB_COM_GROUP)

          if group
            GroupMembersFinder.new(group).execute.pluck(:user_id)
          else
            []
          end
        end
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord
    private_class_method :gitlab_com_user_ids

    def self.expire_allowed_user_ids_cache
      l1_cache_backend.delete(ALLOWED_USER_IDS_KEY)
      l2_cache_backend.delete(ALLOWED_USER_IDS_KEY)
    end

    def self.l1_cache_backend
      Gitlab::ProcessMemoryCache.cache_backend
    end

    def self.l2_cache_backend
      Rails.cache
    end
  end
end
