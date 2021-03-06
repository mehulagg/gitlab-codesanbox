# frozen_string_literal: true

require "spec_helper"

RSpec.describe License do
  let(:gl_license) { build(:gitlab_license) }
  let(:license)    { build(:license, data: gl_license.export) }

  describe "Validation" do
    describe "Valid license" do
      context "when the license is provided" do
        it "is valid" do
          expect(license).to be_valid
        end
      end

      context "when no license is provided" do
        before do
          license.data = nil
        end

        it "is invalid" do
          expect(license).not_to be_valid
        end
      end
    end

    describe '#check_users_limit' do
      using RSpec::Parameterized::TableSyntax

      before do
        create(:group_member, :guest)
        create(:group_member, :reporter)
        create(:license, plan: plan)
      end

      let(:users_count) { nil }
      let(:new_license) do
        gl_license = build(:gitlab_license, restrictions: { plan: plan, active_user_count: users_count, previous_user_count: 1 })
        build(:license, data: gl_license.export)
      end

      where(:gl_plan, :valid) do
        ::License::STARTER_PLAN  | false
        ::License::PREMIUM_PLAN  | false
        ::License::ULTIMATE_PLAN | true
      end

      with_them do
        let(:plan) { gl_plan }

        context 'when license has restricted users' do
          let(:users_count) { 1 }

          it { expect(new_license.valid?).to eq(valid) }
        end

        context 'when license has unlimited users' do
          let(:users_count) { nil }

          it 'is always valid' do
            expect(new_license.valid?).to eq(true)
          end
        end
      end
    end

    describe "Historical active user count" do
      let(:active_user_count) { User.active.count + 10 }
      let(:date)              { described_class.current.starts_at }
      let!(:historical_data)  { HistoricalData.create!(date: date, active_user_count: active_user_count) }

      context "when there is no active user count restriction" do
        it "is valid" do
          expect(license).to be_valid
        end
      end

      context 'without historical data' do
        before do
          create_list(:user, 2)

          gl_license.restrictions = {
            previous_user_count: 1,
            active_user_count: User.active.count - 1
          }

          HistoricalData.delete_all
        end

        context 'with previous_user_count and active users above of license limit' do
          it 'is invalid' do
            expect(license).to be_invalid
          end

          it 'shows the proper error message' do
            license.valid?

            error_msg = "This GitLab installation currently has 2 active users, exceeding this license's limit of 1 by 1 user. " \
                        "Please upload a license for at least 2 users or contact sales at renewals@gitlab.com"

            expect(license.errors[:base].first).to eq(error_msg)
          end
        end
      end

      context "when the active user count restriction is exceeded" do
        before do
          gl_license.restrictions = { active_user_count: active_user_count - 1 }
        end

        context "when the license started" do
          it "is invalid" do
            expect(license).not_to be_valid
          end
        end

        context "after the license started" do
          let(:date) { Date.current }

          it "is valid" do
            expect(license).to be_valid
          end
        end

        context "in the year before the license started" do
          let(:date) { described_class.current.starts_at - 6.months }

          it "is invalid" do
            expect(license).not_to be_valid
          end
        end

        context "earlier than a year before the license started" do
          let(:date) { described_class.current.starts_at - 2.years }

          it "is valid" do
            expect(license).to be_valid
          end
        end
      end

      context "when the active user count restriction is not exceeded" do
        before do
          gl_license.restrictions = { active_user_count: active_user_count + 1 }
        end

        it "is valid" do
          expect(license).to be_valid
        end
      end

      context "when the active user count is met exactly" do
        it "is valid" do
          active_user_count = 100
          gl_license.restrictions = { active_user_count: active_user_count }

          expect(license).to be_valid
        end
      end

      context 'with true-up info' do
        context 'when quantity is ok' do
          before do
            set_restrictions(restricted_user_count: 5, trueup_quantity: 10)
          end

          it 'is valid' do
            expect(license).to be_valid
          end

          context 'but active users exceeds restricted user count' do
            it 'is invalid' do
              create_list(:user, 6)

              expect(license).not_to be_valid
            end
          end
        end

        context 'when quantity is wrong' do
          it 'is invalid' do
            set_restrictions(restricted_user_count: 5, trueup_quantity: 8)

            expect(license).not_to be_valid
          end
        end

        context 'when previous user count is not present' do
          before do
            set_restrictions(restricted_user_count: 5, trueup_quantity: 7)
          end

          it 'uses current active user count to calculate the expected true-up' do
            create_list(:user, 3)

            expect(license).to be_valid
          end

          context 'with wrong true-up quantity' do
            it 'is invalid' do
              create_list(:user, 2)

              expect(license).not_to be_valid
            end
          end
        end

        context 'when previous user count is present' do
          before do
            set_restrictions(restricted_user_count: 5, trueup_quantity: 6, previous_user_count: 4)
          end

          it 'uses it to calculate the expected true-up' do
            expect(license).to be_valid
          end
        end
      end
    end

    describe "Not expired" do
      context "when the license doesn't expire" do
        it "is valid" do
          expect(license).to be_valid
        end
      end

      context "when the license has expired" do
        before do
          gl_license.expires_at = Date.yesterday
        end

        it "is invalid" do
          expect(license).not_to be_valid
        end
      end

      context "when the license has yet to expire" do
        before do
          gl_license.expires_at = Date.tomorrow
        end

        it "is valid" do
          expect(license).to be_valid
        end
      end
    end

    describe 'downgrade' do
      context 'when more users were added in previous period' do
        before do
          HistoricalData.create!(date: described_class.current.starts_at - 6.months, active_user_count: 15)

          set_restrictions(restricted_user_count: 5, previous_user_count: 10)
        end

        it 'is invalid without a true-up' do
          expect(license).not_to be_valid
        end
      end

      context 'when no users were added in the previous period' do
        before do
          HistoricalData.create!(date: 6.months.ago, active_user_count: 15)

          set_restrictions(restricted_user_count: 10, previous_user_count: 15)
        end

        it 'is valid' do
          expect(license).to be_valid
        end
      end
    end
  end

  describe 'Callbacks' do
    describe '#reset_future_dated', :request_store do
      let!(:future_dated_license) { create(:license, data: create(:gitlab_license, starts_at: Date.current + 1.month).export) }

      before do
        described_class.future_dated

        expect(Gitlab::SafeRequestStore.read(:future_dated_license)).to be_present
      end

      context 'when a license is created' do
        it 'deletes the future_dated_license value in Gitlab::SafeRequestStore' do
          create(:license)

          expect(Gitlab::SafeRequestStore.read(:future_dated_license)).to be_nil
        end
      end

      context 'when a license is destroyed' do
        it 'deletes the future_dated_license value in Gitlab::SafeRequestStore' do
          future_dated_license.destroy

          expect(Gitlab::SafeRequestStore.read(:future_dated_license)).to be_nil
        end
      end
    end
  end

  describe "Class methods" do
    before do
      described_class.reset_current
    end

    describe '.features_for_plan' do
      it 'returns features for starter plan' do
        expect(described_class.features_for_plan('starter'))
          .to include(:multiple_issue_assignees)
      end

      it 'returns features for premium plan' do
        expect(described_class.features_for_plan('premium'))
          .to include(:multiple_issue_assignees, :deploy_board, :file_locks)
      end

      it 'returns empty array if no features for given plan' do
        expect(described_class.features_for_plan('bronze')).to eq([])
      end
    end

    describe '.plan_includes_feature?' do
      let(:feature) { :deploy_board }

      subject { described_class.plan_includes_feature?(plan, feature) }

      context 'when addon included' do
        let(:plan) { 'premium' }

        it 'returns true' do
          is_expected.to eq(true)
        end
      end

      context 'when addon not included' do
        let(:plan) { 'starter' }

        it 'returns false' do
          is_expected.to eq(false)
        end
      end

      context 'when plan is not set' do
        let(:plan) { nil }

        it 'returns false' do
          is_expected.to eq(false)
        end
      end

      context 'when feature does not exists' do
        let(:plan) { 'premium' }
        let(:feature) { nil }

        it 'returns false' do
          is_expected.to eq(false)
        end
      end
    end

    describe '.current' do
      context 'when licenses table does not exist' do
        it 'returns nil' do
          allow(described_class).to receive(:table_exists?).and_return(false)

          expect(described_class.current).to be_nil
        end
      end

      context 'when there is no license' do
        it 'returns nil' do
          allow(described_class).to receive(:last_hundred).and_return([])

          expect(described_class.current).to be_nil
        end
      end

      context 'when the license is invalid' do
        it 'returns nil' do
          allow(described_class).to receive(:last_hundred).and_return([license])
          allow(license).to receive(:valid?).and_return(false)

          expect(described_class.current).to be_nil
        end
      end

      context 'when the license is valid' do
        it 'returns the license' do
          current_license = create_list(:license, 2).last
          create(:license, data: create(:gitlab_license, starts_at: Date.current + 1.month).export)

          expect(described_class.current).to eq(current_license)
        end
      end
    end

    describe '.future_dated_only?' do
      before do
        described_class.reset_future_dated
      end

      context 'when licenses table does not exist' do
        it 'returns false' do
          allow(described_class).to receive(:table_exists?).and_return(false)

          expect(described_class.future_dated_only?).to be_falsey
        end
      end

      context 'when there is no license' do
        it 'returns false' do
          allow(described_class).to receive(:last_hundred).and_return([])

          expect(described_class.future_dated_only?).to be_falsey
        end
      end

      context 'when the license is invalid' do
        it 'returns false' do
          license = build(:license, data: build(:gitlab_license, starts_at: Date.current + 1.month).export)

          allow(described_class).to receive(:last_hundred).and_return([license])
          allow(license).to receive(:valid?).and_return(false)

          expect(described_class.future_dated_only?).to be_falsey
        end
      end

      context 'when the license is valid' do
        context 'when there is a current license' do
          it 'returns the false' do
            expect(described_class.future_dated_only?).to be_falsey
          end
        end

        context 'when the license is future-dated' do
          it 'returns the true' do
            create(:license, data: create(:gitlab_license, starts_at: Date.current + 1.month).export)

            allow(described_class).to receive(:current).and_return(nil)

            expect(described_class.future_dated_only?).to be_truthy
          end
        end
      end
    end

    describe '.future_dated' do
      before do
        described_class.reset_future_dated
      end

      context 'when licenses table does not exist' do
        it 'returns nil' do
          allow(described_class).to receive(:table_exists?).and_return(false)

          expect(described_class.future_dated).to be_nil
        end
      end

      context 'when there is no license' do
        it 'returns nil' do
          allow(described_class).to receive(:last_hundred).and_return([])

          expect(described_class.future_dated).to be_nil
        end
      end

      context 'when the license is invalid' do
        it 'returns false' do
          license = build(:license, data: build(:gitlab_license, starts_at: Date.current + 1.month).export)

          allow(described_class).to receive(:last_hundred).and_return([license])
          allow(license).to receive(:valid?).and_return(false)

          expect(described_class.future_dated).to be_nil
        end
      end

      context 'when the license is valid' do
        it 'returns the true' do
          future_dated_license = create(:license, data: create(:gitlab_license, starts_at: Date.current + 1.month).export)

          expect(described_class.future_dated).to eq(future_dated_license)
        end
      end
    end

    describe ".block_changes?" do
      before do
        allow(License).to receive(:current).and_return(license)
      end

      context "when there is no current license" do
        let(:license) { nil }

        it "returns false" do
          expect(described_class.block_changes?).to be_falsey
        end
      end

      context 'with an expired trial license' do
        let!(:license) { create(:license, trial: true) }

        it 'returns false' do
          expect(described_class.block_changes?).to be_falsey
        end
      end

      context 'with an expired normal license' do
        let!(:license) { create(:license, expired: true) }

        it 'returns true' do
          expect(described_class.block_changes?).to eq(true)
        end
      end

      context "when the current license is set to block changes" do
        before do
          allow(license).to receive(:block_changes?).and_return(true)
        end

        it "returns true" do
          expect(described_class.block_changes?).to be_truthy
        end
      end

      context "when the current license doesn't block changes" do
        it "returns false" do
          expect(described_class.block_changes?).to be_falsey
        end
      end
    end

    describe '.global_feature?' do
      subject { described_class.global_feature?(feature) }

      context 'when it is a global feature' do
        let(:feature) { :geo }

        it { is_expected.to be(true) }
      end

      context 'when it is not a global feature' do
        let(:feature) { :sast }

        it { is_expected.to be(false) }
      end
    end
  end

  describe "#md5" do
    it "returns the same MD5 for licenses with carriage returns and those without" do
      other_license = build(:license, data: license.data.gsub("\n", "\r\n"))

      expect(other_license.md5).to eq(license.md5)
    end

    it "returns the same MD5 for licenses with trailing newlines and those without" do
      other_license = build(:license, data: license.data.chomp)

      expect(other_license.md5).to eq(license.md5)
    end

    it "returns the same MD5 for licenses with multiple trailing newlines and those with a single trailing newline" do
      other_license = build(:license, data: "#{license.data}\n\n\n")

      expect(other_license.md5).to eq(license.md5)
    end
  end

  describe "#license" do
    context "when no data is provided" do
      before do
        license.data = nil
      end

      it "returns nil" do
        expect(license.license).to be_nil
      end
    end

    context "when corrupt license data is provided" do
      before do
        license.data = "whatever"
      end

      it "returns nil" do
        expect(license.license).to be_nil
      end
    end

    context "when valid license data is provided" do
      it "returns the license" do
        expect(license.license).not_to be_nil
      end
    end
  end

  describe 'reading add-ons' do
    describe '#plan' do
      let(:gl_license) { build(:gitlab_license, restrictions: restrictions.merge(add_ons: {})) }
      let(:license)    { build(:license, data: gl_license.export) }

      subject { license.plan }

      [
        { restrictions: {},                  plan: License::STARTER_PLAN },
        { restrictions: { plan: nil },       plan: License::STARTER_PLAN },
        { restrictions: { plan: '' },        plan: License::STARTER_PLAN },
        { restrictions: { plan: 'unknown' }, plan: 'unknown' }
      ].each do |spec|
        context spec.inspect do
          let(:restrictions) { spec[:restrictions] }

          it { is_expected.to eq(spec[:plan]) }
        end
      end
    end

    describe '#features_from_add_ons' do
      context 'without add-ons' do
        it 'returns an empty array' do
          license = build_license_with_add_ons({}, plan: 'unknown')

          expect(license.features_from_add_ons).to eq([])
        end
      end

      context 'with add-ons' do
        it 'returns all available add-ons' do
          license = build_license_with_add_ons({ 'GitLab_DeployBoard' => 1, 'GitLab_FileLocks' => 2 })

          expect(license.features_from_add_ons).to match_array([:deploy_board, :file_locks])
        end
      end

      context 'with nil add-ons' do
        it 'returns an empty array' do
          license = build_license_with_add_ons({ 'GitLab_DeployBoard' => nil, 'GitLab_FileLocks' => nil })

          expect(license.features_from_add_ons).to eq([])
        end
      end
    end

    describe '#feature_available?' do
      it 'returns true if add-on exists and have a quantity greater than 0' do
        license = build_license_with_add_ons({ 'GitLab_DeployBoard' => 1 })

        expect(license.feature_available?(:deploy_board)).to eq(true)
      end

      it 'returns true if the feature is included in the plan do' do
        license = build_license_with_add_ons({}, plan: License::PREMIUM_PLAN)

        expect(license.feature_available?(:auditor_user)).to eq(true)
      end

      it 'returns false if add-on exists but have a quantity of 0' do
        license = build_license_with_add_ons({ 'GitLab_DeployBoard' => 0 })

        expect(license.feature_available?(:deploy_board)).to eq(false)
      end

      it 'returns false if add-on does not exists' do
        license = build_license_with_add_ons({})

        expect(license.feature_available?(:deploy_board)).to eq(false)
        expect(license.feature_available?(:auditor_user)).to eq(false)
      end

      context 'with an expired trial license' do
        let(:license) { create(:license, trial: true, expired: true) }

        before(:all) do
          described_class.delete_all
        end

        ::License::EES_FEATURES.each do |feature|
          it "returns false for #{feature}" do
            expect(license.feature_available?(feature)).to eq(false)
          end
        end
      end

      context 'when feature is disabled by a feature flag' do
        it 'returns false' do
          feature = license.features.first
          stub_feature_flags(feature => false)

          expect(license.features).not_to receive(:include?)

          expect(license.feature_available?(feature)).to eq(false)
        end
      end

      context 'when feature is enabled by a feature flag' do
        it 'returns true' do
          feature = license.features.first
          stub_feature_flags(feature => true)

          expect(license.feature_available?(feature)).to eq(true)
        end
      end
    end

    def build_license_with_add_ons(add_ons, plan: nil)
      gl_license = build(:gitlab_license, restrictions: { add_ons: add_ons, plan: plan })
      build(:license, data: gl_license.export)
    end
  end

  describe '#overage' do
    it 'returns 0 if restricted_user_count is nil' do
      allow(license).to receive(:restricted_user_count) { nil }

      expect(license.overage).to eq(0)
    end

    it 'returns the difference between user_count and restricted_user_count' do
      allow(license).to receive(:restricted_user_count) { 10 }

      expect(license.overage(14)).to eq(4)
    end

    it 'returns the difference using current_active_users_count as user_count if no user_count argument provided' do
      allow(license).to receive(:current_active_users_count) { 110 }
      allow(license).to receive(:restricted_user_count) { 100 }

      expect(license.overage).to eq(10)
    end

    it 'returns 0 if the difference is a negative number' do
      allow(license).to receive(:restricted_user_count) { 2 }

      expect(license.overage(1)).to eq(0)
    end
  end

  describe '#maximum_user_count' do
    using RSpec::Parameterized::TableSyntax

    subject { license.maximum_user_count }

    where(:current_active_users_count, :historical_max, :expected) do
      100 | 50  | 100
      50  | 100 | 100
      50  | 50  | 50
    end

    with_them do
      before do
        allow(license).to receive(:current_active_users_count) { current_active_users_count }
        allow(license).to receive(:historical_max) { historical_max }
      end

      it { is_expected.to eq(expected) }
    end
  end

  describe '#ultimate?' do
    using RSpec::Parameterized::TableSyntax

    let(:license) { build(:license, plan: plan) }

    subject { license.ultimate? }

    where(:plan, :expected) do
      nil | false
      described_class::STARTER_PLAN | false
      described_class::PREMIUM_PLAN | false
      described_class::ULTIMATE_PLAN | true
    end

    with_them do
      it { is_expected.to eq(expected) }
    end
  end

  describe 'Trial Licenses' do
    before do
      ApplicationSetting.create_from_defaults
      stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    end

    describe 'Update trial setting' do
      context 'when the license is not trial' do
        before do
          gl_license.restrictions = { trial: false }
          gl_license.expires_at = Date.tomorrow
        end

        it 'returns nil' do
          updated = license.update_trial_setting
          expect(updated).to be_nil
          expect(ApplicationSetting.current.license_trial_ends_on).to be_nil
        end
      end

      context 'when the license is the very first trial' do
        let(:tomorrow) { Date.tomorrow }

        before do
          gl_license.restrictions = { trial: true }
          gl_license.expires_at = tomorrow
        end

        it 'is eligible for trial' do
          expect(described_class.eligible_for_trial?).to be_truthy
        end

        it 'updates the trial setting' do
          updated = license.update_trial_setting

          expect(updated).to be_truthy
          expect(described_class.eligible_for_trial?).to be_falsey
          expect(ApplicationSetting.current.license_trial_ends_on).to eq(tomorrow)
        end
      end

      context 'when the license is a repeated trial' do
        let(:yesterday) { Date.yesterday }

        before do
          gl_license.restrictions = { trial: true }
          gl_license.expires_at = Date.tomorrow
          ApplicationSetting.current.update license_trial_ends_on: yesterday
        end

        it 'does not update existing trial setting' do
          updated = license.update_trial_setting
          expect(updated).to be_falsey
          expect(ApplicationSetting.current.license_trial_ends_on).to eq(yesterday)
        end

        it 'is not eligible for trial' do
          expect(described_class.eligible_for_trial?).to be_falsey
        end
      end
    end
  end

  describe '.history' do
    before(:all) do
      described_class.delete_all
    end

    it 'returns the licenses sorted by created_at, starts_at and expires_at descending' do
      today = Date.current
      now = Time.current

      past_license = create(:license, created_at: now - 1.month, data: build(:gitlab_license, starts_at: today - 1.month, expires_at: today + 11.months).export)
      expired_license = create(:license, created_at: now, data: build(:gitlab_license, starts_at: today - 1.year, expires_at: today - 1.month).export)
      future_license = create(:license, created_at: now, data: build(:gitlab_license, starts_at: today + 1.month, expires_at: today + 13.months).export)
      another_license = create(:license, created_at: now, data: build(:gitlab_license, starts_at: today - 1.month, expires_at: today + 1.year).export)
      current_license = create(:license, created_at: now, data: build(:gitlab_license, starts_at: today - 15.days, expires_at: today + 11.months).export)

      expect(described_class.history.map(&:id)).to eq(
        [
          future_license.id,
          current_license.id,
          another_license.id,
          past_license.id,
          expired_license.id
        ]
      )
    end
  end

  describe '#edition' do
    let(:ultimate) { build(:license, plan: 'ultimate') }
    let(:premium) { build(:license, plan: 'premium') }
    let(:starter) { build(:license, plan: 'starter') }
    let(:old) { build(:license, plan: 'other') }

    it 'have expected values' do
      expect(ultimate.edition).to eq('EEU')
      expect(premium.edition).to eq('EEP')
      expect(starter.edition).to eq('EES')
      expect(old.edition).to eq('EE')
    end
  end

  def set_restrictions(opts)
    date = described_class.current.starts_at

    gl_license.restrictions = {
      active_user_count: opts[:restricted_user_count],
      previous_user_count: opts[:previous_user_count],
      trueup_quantity: opts[:trueup_quantity],
      trueup_from: (date - 1.year).to_s,
      trueup_to: date.to_s
    }
  end

  describe '#paid?' do
    using RSpec::Parameterized::TableSyntax

    where(:plan, :paid_result) do
      License::STARTER_PLAN  | true
      License::PREMIUM_PLAN  | true
      License::ULTIMATE_PLAN | true
      nil                    | true
    end

    with_them do
      let(:license) { build(:license, plan: plan) }

      subject { license.paid? }

      it do
        is_expected.to eq(paid_result)
      end
    end
  end

  describe '#started?' do
    using RSpec::Parameterized::TableSyntax

    where(:starts_at, :result) do
      Date.current - 1.month | true
      Date.current           | true
      Date.current + 1.month | false
    end

    with_them do
      let(:gl_license) { build(:gitlab_license, starts_at: starts_at) }

      subject { license.started? }

      it do
        is_expected.to eq(result)
      end
    end
  end

  describe '#future_dated?' do
    using RSpec::Parameterized::TableSyntax

    where(:starts_at, :result) do
      Date.current - 1.month | false
      Date.current           | false
      Date.current + 1.month | true
    end

    with_them do
      let(:gl_license) { build(:gitlab_license, starts_at: starts_at) }

      subject { license.future_dated? }

      it do
        is_expected.to eq(result)
      end
    end
  end

  describe '#auto_renew' do
    it 'is false' do
      expect(license.auto_renew).to be false
    end
  end

  describe '#active_user_count_threshold' do
    subject { license.active_user_count_threshold }

    it 'returns nil for license with unlimited user count' do
      allow(license).to receive(:restricted_user_count).and_return(nil)

      expect(subject).to be_nil
    end

    context 'for license with users' do
      using RSpec::Parameterized::TableSyntax

      where(:restricted_user_count, :active_user_count, :percentage, :threshold_value) do
        3    | 2    | false | 1
        20   | 18   | false | 2
        90   | 80   | true  | 10
        300  | 275  | true  | 8
        1200 | 1100 | true  | 5
      end

      with_them do
        before do
          allow(license).to receive(:restricted_user_count).and_return(restricted_user_count)
          allow(license).to receive(:current_active_users_count).and_return(active_user_count)
        end

        it { is_expected.not_to be_nil }
        it { is_expected.to include(value: threshold_value, percentage: percentage) }
      end
    end
  end

  describe '#active_user_count_threshold_reached?' do
    using RSpec::Parameterized::TableSyntax

    subject { license.active_user_count_threshold_reached? }

    where(:restricted_user_count, :current_active_users_count, :result) do
      10   | 9   | true
      nil  | 9   | false
      10   | 15  | false
      100  | 95  | true
    end

    with_them do
      before do
        allow(license).to receive(:current_active_users_count).and_return(current_active_users_count)
        allow(license).to receive(:restricted_user_count).and_return(restricted_user_count)
      end

      it { is_expected.to eq(result) }
    end
  end
end
