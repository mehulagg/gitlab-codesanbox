# frozen_string_literal: true

module EE
  module Issue
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      WEIGHT_RANGE = (0..20).freeze
      WEIGHT_ALL = 'Everything'.freeze
      WEIGHT_ANY = 'Any'.freeze
      WEIGHT_NONE = 'None'.freeze
      ELASTICSEARCH_PERMISSION_TRACKED_FIELDS = %w(assignee_ids author_id confidential).freeze

      include Elastic::ApplicationVersionedSearch
      include UsageStatistics
      include WeightEventable
      include IterationEventable
      include HealthStatus

      scope :order_blocking_issues_desc, -> { reorder(blocking_issues_count: :desc) }
      scope :order_weight_desc, -> { reorder ::Gitlab::Database.nulls_last_order('weight', 'DESC') }
      scope :order_weight_asc, -> { reorder ::Gitlab::Database.nulls_last_order('weight') }
      scope :no_epic, -> { left_outer_joins(:epic_issue).where(epic_issues: { epic_id: nil }) }
      scope :any_epic, -> { joins(:epic_issue) }
      scope :in_epics, ->(epics) { joins(:epic_issue).where(epic_issues: { epic_id: epics }) }
      scope :no_iteration, -> { where(sprint_id: nil) }
      scope :any_iteration, -> { where.not(sprint_id: nil) }
      scope :in_iterations, ->(iterations) { where(sprint_id: iterations) }
      scope :on_status_page, -> do
        joins(project: :status_page_setting)
        .where(status_page_settings: { enabled: true })
        .joins(:status_page_published_incident)
        .public_only
      end
      scope :counts_by_health_status, -> { reorder(nil).group(:health_status).count }
      scope :with_health_status, -> { where.not(health_status: nil) }
      scope :distinct_epic_ids, -> do
        epic_ids = except(:order, :select).joins(:epic_issue).reselect('epic_issues.epic_id').distinct
        epic_ids = epic_ids.group('epic_issues.epic_id') if epic_ids.group_values.present?

        epic_ids
      end

      has_one :epic_issue
      has_one :epic, through: :epic_issue
      belongs_to :promoted_to_epic, class_name: 'Epic'

      has_one :status_page_published_incident, class_name: 'StatusPage::PublishedIncident', inverse_of: :issue

      has_many :vulnerability_links, class_name: 'Vulnerabilities::IssueLink', inverse_of: :issue
      has_many :related_vulnerabilities, through: :vulnerability_links, source: :vulnerability

      has_many :feature_flag_issues
      has_many :feature_flags, through: :feature_flag_issues, class_name: '::Operations::FeatureFlag'

      validates :weight, allow_nil: true, numericality: { greater_than_or_equal_to: 0 }
      validate :validate_confidential_epic

      after_create :update_generic_alert_title, if: :generic_alert_with_default_title?
    end

    class_methods do
      def with_api_entity_associations
        super.preload(:epic)
      end
    end

    # override
    def check_for_spam?
      author.bot? || super
    end

    # override
    def allows_multiple_assignees?
      project.feature_available?(:multiple_issue_assignees)
    end

    def blocked?
      blocking_issues_ids.any?
    end

    # Used on EE::IssueEntity to expose blocking issues URLs
    def blocked_by_issues(user)
      return ::Issue.none unless blocked?

      issues =
        ::IssuesFinder.new(user).execute.where(id: blocking_issues_ids)

      issues.preload(project: [:route, { namespace: [:route] }])
    end

    # override
    def subscribed_without_subscriptions?(user, *)
      # TODO: this really shouldn't be necessary, because the support
      # bot should be a participant (which is what the superclass
      # method checks for). However, the support bot gets filtered out
      # at the end of Participable#raw_participants as not being able
      # to read the project. Overriding *that* behavior is problematic
      # because it doesn't use the Policy framework, and instead uses a
      # custom-coded Ability.users_that_can_read_project, which is...
      # a pain to override in EE. So... here we say, the support bot
      # is subscribed by default, until an unsubscribed record appears,
      # even though it's not *technically* a participant in this issue.

      # Making the support bot subscribed to every issue is not as bad as it
      # seems, though, since it isn't permitted to :receive_notifications,
      # and doesn't actually show up in the participants list.
      user.bot? || super
    end

    # override
    def weight
      super if weight_available?
    end

    # override
    def maintain_elasticsearch_update
      super

      maintain_elasticsearch_issue_notes_update if elasticsearch_issue_notes_need_updating?
    end

    def maintain_elasticsearch_issue_notes_update
      ::Note.searchable.where(noteable: self).find_each do |note|
        note.maintain_elasticsearch_update
      end
    end

    def elasticsearch_issue_notes_need_updating?
      changed_fields = self.previous_changes.keys
      changed_fields && (changed_fields & ELASTICSEARCH_PERMISSION_TRACKED_FIELDS).any?
    end

    override :supports_weight?
    def supports_weight?
      !incident?
    end

    def supports_iterations?
      !incident?
    end

    def can_assign_epic?(user)
      user&.can?(:admin_epic, project.group)
    end

    # Issue position on boards list should be relative to all group projects
    def parent_ids
      return super unless has_group_boards?

      board_group.all_projects.select(:id)
    end

    def has_group_boards?
      board_group && board_group.boards.any?
    end

    def board_group
      @group ||= project.group
    end

    def promoted?
      !!promoted_to_epic_id
    end

    class_methods do
      extend ::Gitlab::Utils::Override

      override :simple_sorts
      def simple_sorts
        super.merge(
          {
            'weight' => -> { order_weight_asc.with_order_id_desc },
            'weight_asc' => -> { order_weight_asc.with_order_id_desc },
            'weight_desc' => -> { order_weight_desc.with_order_id_desc }
          }
        )
      end

      override :sort_by_attribute
      def sort_by_attribute(method, excluded_labels: [])
        case method.to_s
        when 'blocking_issues_desc' then order_blocking_issues_desc.with_order_id_desc
        when 'weight', 'weight_asc' then order_weight_asc.with_order_id_desc
        when 'weight_desc'          then order_weight_desc.with_order_id_desc
        else
          super
        end
      end

      def weight_options
        [WEIGHT_NONE] + WEIGHT_RANGE.to_a
      end
    end

    def update_blocking_issues_count!
      blocking_count = ::IssueLink.blocking_issues_count_for(self)

      update!(blocking_issues_count: blocking_count)
    end

    private

    def blocking_issues_ids
      @blocking_issues_ids ||= ::IssueLink.blocking_issue_ids_for(self)
    end

    def update_generic_alert_title
      update(title: "#{title} #{iid}")
    end

    def generic_alert_with_default_title?
      title == ::Gitlab::Alerting::NotificationPayloadParser::DEFAULT_TITLE &&
        project.alerts_service_activated? &&
        author == ::User.alert_bot
    end

    def validate_confidential_epic
      return unless epic

      if !confidential? && epic.confidential?
        errors.add :issue, _('Cannot set confidential epic for a non-confidential issue')
      end
    end
  end
end
