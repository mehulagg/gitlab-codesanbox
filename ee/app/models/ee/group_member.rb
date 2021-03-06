# frozen_string_literal: true

module EE
  module GroupMember
    extend ActiveSupport::Concern

    prepended do
      extend ::Gitlab::Utils::Override
      include UsageStatistics

      validate :sso_enforcement, if: :group
      validate :group_domain_limitations, if: :group_has_domain_limitations?

      scope :by_group_ids, ->(group_ids) { where(source_id: group_ids) }

      scope :with_ldap_dn, -> { joins(user: :identities).where("identities.provider LIKE ?", 'ldap%') }
      scope :with_identity_provider, ->(provider) do
        joins(user: :identities).where(identities: { provider: provider })
      end
      scope :with_saml_identity, ->(provider) do
        joins(user: :identities).where(identities: { saml_provider_id: provider })
      end

      scope :reporters, -> { where(access_level: ::Gitlab::Access::REPORTER) }
      scope :non_owners, -> { where("members.access_level < ?", ::Gitlab::Access::OWNER) }
      scope :by_user_id, ->(user_id) { where(user_id: user_id) }
    end

    class_methods do
      def member_of_group?(group, user)
        exists?(group: group, user: user)
      end
    end

    def group_has_domain_limitations?
      group.feature_available?(:group_allowed_email_domains) && group_allowed_email_domains.any?
    end

    def group_domain_limitations
      if user
        validate_users_email
        validate_email_verified
      else
        validate_invitation_email
      end
    end

    def validate_email_verified
      return if user.primary_email_verified?

      # Do not validate if emails are verified
      # for users created via SAML/SCIM.
      return if group_saml_identity.present?
      return if source.scim_identities.for_user(user).exists?

      errors.add(:user, email_not_verified)
    end

    def validate_users_email
      return if matches_at_least_one_group_allowed_email_domain?(user.email)

      errors.add(:user, email_does_not_match_any_allowed_domains(user.email))
    end

    def validate_invitation_email
      return if matches_at_least_one_group_allowed_email_domain?(invite_email)

      errors.add(:invite_email, email_does_not_match_any_allowed_domains(invite_email))
    end

    def group_saml_identity
      return unless source.saml_provider

      if user.group_saml_identities.loaded?
        user.group_saml_identities.detect { |i| i.saml_provider_id == source.saml_provider.id }
      else
        user.group_saml_identities.find_by(saml_provider: source.saml_provider)
      end
    end

    private

    def email_does_not_match_any_allowed_domains(email)
      _("email '%{email}' does not match the allowed domains of %{email_domains}" %
        { email: email, email_domains: ::Gitlab::Utils.to_exclusive_sentence(group_allowed_email_domains.map(&:domain)) })
    end

    def email_not_verified
      _("email '%{email}' is not a verified email." % { email: user.email })
    end

    def group_allowed_email_domains
      group.root_ancestor_allowed_email_domains
    end

    def matches_at_least_one_group_allowed_email_domain?(email)
      group_allowed_email_domains.any? do |allowed_email_domain|
        allowed_email_domain.email_matches_domain?(email)
      end
    end
  end
end
