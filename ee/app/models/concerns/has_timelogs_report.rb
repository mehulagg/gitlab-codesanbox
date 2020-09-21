# frozen_string_literal: true

module HasTimelogsReport
  extend ActiveSupport::Concern

  def timelogs(start_time, end_time)
    @timelogs ||= timelogs_for(start_time, end_time)
  end

  def user_can_access_group_timelogs?(current_user)
    return unless feature_available?(:group_timelogs)

    Ability.allowed?(current_user, :read_group_timelogs, self)
  end

  private

  def timelogs_for(start_time, end_time)
    Timelog.between_times(start_time, end_time).for_issues_in_group(self)
  end
end
