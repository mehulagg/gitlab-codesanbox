# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issue do
  include ExternalAuthorizationServiceHelpers

  using RSpec::Parameterized::TableSyntax

  describe 'associations' do
    subject { build(:issue) }

    it { is_expected.to have_many(:resource_weight_events) }
    it { is_expected.to have_many(:resource_iteration_events) }
  end

  describe 'modules' do
    subject { build(:issue) }

    it { is_expected.to include_module(EE::WeightEventable) }
  end

  context 'callbacks' do
    describe '.after_create' do
      let_it_be(:project) { create(:project) }
      let(:author) { User.alert_bot }

      context 'when issue title is "New: Incident"' do
        let(:issue) { build(:issue, project: project, author: author, title: 'New: Incident', iid: 503503) }

        context 'when alerts service is active' do
          before do
            allow(project).to receive(:alerts_service_activated?).and_return(true)
          end

          context 'when the author is Alert Bot' do
            it 'updates issue title with the IID' do
              expect { issue.save }.to change { issue.title }.to("New: Incident 503503")
            end
          end

          context 'when the author is not an Alert Bot' do
            let(:author) { create(:user) }

            it 'does not change issue title' do
              expect { issue.save }.not_to change { issue.title }
            end
          end
        end

        context 'when alerts service is not active' do
          before do
            allow(project).to receive(:alerts_service_activated?).and_return(false)
          end

          it 'does not change issue title' do
            expect { issue.save }.not_to change { issue.title }
          end
        end
      end

      context 'when issue title is not "New: Incident"' do
        let(:issue) { build(:issue, project: project, title: 'Not New: Incident') }

        it 'does not change issue title' do
          expect { issue.save }.not_to change { issue.title }
        end
      end
    end
  end

  context 'scopes' do
    describe '.counts_by_health_status' do
      it 'returns counts grouped by health_status' do
        create(:issue, health_status: :on_track)
        create(:issue, health_status: :on_track)
        create(:issue, health_status: :at_risk)

        expect(Issue.counts_by_health_status).to eq({ 'on_track' => 2, 'at_risk' => 1 } )
      end
    end

    describe '.on_status_page' do
      let_it_be(:status_page_setting) { create(:status_page_setting, :enabled) }
      let_it_be(:project) { status_page_setting.project }
      let_it_be(:published_issue) { create(:issue, :published, project: project) }
      let_it_be(:confidential_issue) { create(:issue, :published, :confidential, project: project) }
      let_it_be(:nonpublished_issue) { create(:issue, project: project) }

      it { expect(Issue.on_status_page.count).to eq(1) }
      it { expect(Issue.on_status_page.first).to eq(published_issue) }

      context 'with status page disabled' do
        before do
          status_page_setting.update!(enabled: false)
        end

        it { expect(Issue.on_status_page.count).to eq(0) }
      end
    end

    context 'epics' do
      let_it_be(:epic1) { create(:epic) }
      let_it_be(:epic2) { create(:epic) }
      let_it_be(:epic_issue1) { create(:epic_issue, epic: epic1) }
      let_it_be(:epic_issue2) { create(:epic_issue, epic: epic2) }
      let_it_be(:issue_no_epic) { create(:issue) }

      before do
        stub_licensed_features(epics: true)
      end

      describe '.no_epic' do
        it 'returns only issues without an epic assigned' do
          expect(described_class.count).to eq 3
          expect(described_class.no_epic).to eq [issue_no_epic]
        end
      end

      describe '.any_epic' do
        it 'returns only issues with an epic assigned' do
          expect(described_class.count).to eq 3
          expect(described_class.any_epic).to eq [epic_issue1.issue, epic_issue2.issue]
        end
      end

      describe '.in_epics' do
        it 'returns only issues in selected epics' do
          expect(described_class.count).to eq 3
          expect(described_class.in_epics([epic1])).to eq [epic_issue1.issue]
        end
      end

      describe '.distinct_epic_ids' do
        it 'returns distinct epic ids' do
          expect(described_class.distinct_epic_ids.map(&:epic_id)).to match_array([epic1.id, epic2.id])
        end

        context 'when issues are grouped by labels' do
          let_it_be(:label_link1) { create(:label_link, target: epic_issue1.issue) }
          let_it_be(:label_link2) { create(:label_link, target: epic_issue1.issue) }

          it 'respects query grouping and returns distinct epic ids' do
            ids = described_class.with_label(
              [label_link1.label.title, label_link2.label.title]
            ).distinct_epic_ids.map(&:epic_id)
            expect(ids).to eq([epic1.id])
          end
        end
      end
    end

    context 'iterations' do
      let_it_be(:iteration1) { create(:iteration) }
      let_it_be(:iteration2) { create(:iteration) }
      let_it_be(:iteration1_issue) { create(:issue, iteration: iteration1) }
      let_it_be(:iteration2_issue) { create(:issue, iteration: iteration2) }
      let_it_be(:issue_no_iteration) { create(:issue) }

      before do
        stub_licensed_features(iterations: true)
      end

      describe '.no_iteration' do
        it 'returns only issues without an iteration assigned' do
          expect(described_class.count).to eq 3
          expect(described_class.no_iteration).to eq [issue_no_iteration]
        end
      end

      describe '.any_iteration' do
        it 'returns only issues with an iteration assigned' do
          expect(described_class.count).to eq 3
          expect(described_class.any_iteration).to contain_exactly(iteration1_issue, iteration2_issue)
        end
      end

      describe '.in_iterations' do
        it 'returns only issues in selected iterations' do
          expect(described_class.count).to eq 3
          expect(described_class.in_iterations([iteration1])).to eq [iteration1_issue]
        end
      end
    end
  end

  describe 'validations' do
    describe 'weight' do
      subject { build(:issue) }

      it 'is not valid when negative number' do
        subject.weight = -1

        expect(subject).not_to be_valid
        expect(subject.errors[:weight]).not_to be_empty
      end

      it 'is valid when non-negative' do
        subject.weight = 0

        expect(subject).to be_valid

        subject.weight = 1

        expect(subject).to be_valid
      end
    end

    describe 'confidential' do
      subject { build(:issue, :confidential) }

      it 'is valid when changing to non-confidential and is associated with non-confidential epic' do
        subject.epic = build(:epic)

        subject.confidential = false

        expect(subject).to be_valid
      end

      it 'is not valid when changing to non-confidential and is associated with confidential epic' do
        subject.epic = build(:epic, :confidential)

        subject.confidential = false

        expect(subject).not_to be_valid
      end
    end
  end

  describe 'relations' do
    it { is_expected.to have_many(:vulnerability_links).class_name('Vulnerabilities::IssueLink').inverse_of(:issue) }
    it { is_expected.to have_many(:related_vulnerabilities).through(:vulnerability_links).source(:vulnerability) }
    it { is_expected.to belong_to(:promoted_to_epic).class_name('Epic') }
    it { is_expected.to have_many(:resource_weight_events) }
    it { is_expected.to have_one(:status_page_published_incident) }
  end

  it_behaves_like 'an editable mentionable with EE-specific mentions' do
    subject { create(:issue, project: create(:project, :repository)) }

    let(:backref_text) { "issue #{subject.to_reference}" }
    let(:set_mentionable_text) { ->(txt) { subject.description = txt } }
  end

  describe '#allows_multiple_assignees?' do
    it 'does not allow multiple assignees without license' do
      stub_licensed_features(multiple_issue_assignees: false)

      issue = build(:issue)

      expect(issue.allows_multiple_assignees?).to be_falsey
    end

    it 'does not allow multiple assignees without license' do
      stub_licensed_features(multiple_issue_assignees: true)

      issue = build(:issue)

      expect(issue.allows_multiple_assignees?).to be_truthy
    end
  end

  describe '.simple_sorts' do
    it 'includes weight with other base keys' do
      expect(Issue.simple_sorts.keys).to match_array(
        %w(created_asc created_at_asc created_date created_desc created_at_desc
           closest_future_date closest_future_date_asc due_date due_date_asc due_date_desc
           id_asc id_desc relative_position relative_position_asc
           updated_desc updated_asc updated_at_asc updated_at_desc
           weight weight_asc weight_desc))
    end
  end

  describe '#sort' do
    let(:project) { create(:project) }

    context "by weight" do
      let!(:issue)  { create(:issue, project: project) }
      let!(:issue2) { create(:issue, weight: 1, project: project) }
      let!(:issue3) { create(:issue, weight: 2, project: project) }
      let!(:issue4) { create(:issue, weight: 3, project: project) }

      it "sorts desc" do
        issues = project.issues.sort_by_attribute('weight_desc')
        expect(issues).to eq([issue4, issue3, issue2, issue])
      end

      it "sorts asc" do
        issues = project.issues.sort_by_attribute('weight_asc')
        expect(issues).to eq([issue2, issue3, issue4, issue])
      end
    end

    context 'when weight is the same' do
      subject { project.issues.sort_by_attribute(sorting_param) }

      let!(:issue)  { create(:issue, project: project) }
      let!(:issue2) { create(:issue, weight: 1, project: project) }
      let!(:issue3) { create(:issue, weight: 1, project: project) }
      let!(:issue4) { create(:issue, weight: 1, project: project) }

      context 'sorting by asc' do
        let(:sorting_param) { 'weight_asc' }

        it 'arranges issues with the same weight by their ids' do
          is_expected.to eq([issue4, issue3, issue2, issue])
        end
      end

      context 'sorting by desc' do
        let(:sorting_param) { 'weight_desc' }

        it 'arranges issues with the same weight by their ids' do
          is_expected.to eq([issue4, issue3, issue2, issue])
        end
      end
    end

    context 'by blocking issues' do
      it 'orders by descending blocking issues count' do
        issue_1 = create(:issue, blocking_issues_count: 3)
        issue_2 = create(:issue, blocking_issues_count: 2)

        results = described_class.sort_by_attribute('blocking_issues_desc')

        expect(results.first).to eq(issue_1)
        expect(results.second).to eq(issue_2)
      end
    end
  end

  describe '#weight' do
    where(:license_value, :database_value, :expected) do
      true  | 5   | 5
      true  | nil | nil
      false | 5   | nil
      false | nil | nil
    end

    with_them do
      let(:issue) { build(:issue, weight: database_value) }

      subject { issue.weight }

      before do
        stub_licensed_features(issue_weights: license_value)
      end

      it { is_expected.to eq(expected) }
    end
  end

  describe '#promoted?' do
    let(:issue) { create(:issue) }

    subject { issue.promoted? }

    context 'issue not promoted' do
      it { is_expected.to be_falsey }
    end

    context 'issue promoted' do
      let(:promoted_to_epic) { create(:epic) }
      let(:issue) { create(:issue, promoted_to_epic: promoted_to_epic) }

      it { is_expected.to be_truthy }
    end
  end

  context 'ES related specs', :elastic do
    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
    end

    context 'when updating an Issue' do
      let(:project) { create(:project, :public) }
      let(:issue) { create(:issue, project: project, confidential: true) }

      before do
        Sidekiq::Testing.disable! do
          create(:note, note: 'the_normal_note', noteable: issue, project: project)
        end
        Sidekiq::Testing.inline! do
          project.maintain_elasticsearch_update

          issue.update!(update_field => update_value)
          ensure_elasticsearch_index!
        end
      end

      context 'when changing the confidential value' do
        let(:update_field) { :confidential }
        let(:update_value) { false }

        it 'updates issue notes excluding system notes' do
          expect(issue.elasticsearch_issue_notes_need_updating?).to eq(true)
          expect(Note.elastic_search('the_normal_note', options: { project_ids: [issue.project.id] }).present?).to eq(true)
        end
      end

      context 'when changing the title' do
        let(:update_field) { :title }
        let(:update_value) { 'abc' }

        it 'does not update issue notes' do
          expect(issue.elasticsearch_issue_notes_need_updating?).to eq(false)
          expect(Note.elastic_search('the_normal_note', options: { project_ids: [issue.project.id] }).present?).to eq(false)
        end
      end
    end
  end

  describe 'relative positioning with group boards' do
    let_it_be(:group) { create(:group) }
    let_it_be(:board) { create(:board, group: group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:project1) { create(:project, namespace: group) }
    let_it_be_with_reload(:issue) { create(:issue, project: project) }
    let_it_be_with_reload(:issue1) { create(:issue, project: project1, relative_position: issue.relative_position + RelativePositioning::IDEAL_DISTANCE) }
    let(:new_issue) { build(:issue, project: project1, relative_position: nil) }

    describe '.relative_positioning_query_base' do
      it 'includes cross project issues in the same group' do
        siblings = Issue.relative_positioning_query_base(issue)

        expect(siblings).to include(issue1)
      end
    end

    describe '#move_before' do
      it 'moves issue before' do
        [issue1, issue].each(&:move_to_end)

        issue.move_before(issue1)

        expect(issue.relative_position).to be < issue1.relative_position
      end
    end

    describe '#move_after' do
      it 'moves issue after' do
        [issue, issue1].each(&:move_to_end)

        issue.move_after(issue1)

        expect(issue.relative_position).to be > issue1.relative_position
      end
    end

    describe '#move_to_end' do
      it 'moves issue to the end' do
        new_issue.move_to_end

        expect(new_issue.relative_position).to be > issue1.relative_position
      end
    end

    describe '#move_between' do
      it 'positions issue between two other' do
        new_issue.move_between(issue, issue1)

        expect(new_issue.relative_position).to be > issue.relative_position
        expect(new_issue.relative_position).to be < issue1.relative_position
      end

      it 'positions issue between on top' do
        new_issue.move_between(nil, issue)

        expect(new_issue.relative_position).to be < issue.relative_position
      end

      it 'positions issue between to end' do
        new_issue.move_between(issue1, nil)

        expect(new_issue.relative_position).to be > issue1.relative_position
      end

      it 'positions issues even when after and before positions are the same' do
        issue1.update relative_position: issue.relative_position

        new_issue.move_between(issue, issue1)
        [issue, issue1].each(&:reset)

        expect(new_issue.relative_position)
          .to be_between(issue.relative_position, issue1.relative_position).exclusive
      end

      it 'positions issues between other two if distance is 1' do
        issue1.update relative_position: issue.relative_position + 1

        new_issue.move_between(issue, issue1)
        [issue, issue1].each(&:reset)

        expect(new_issue.relative_position)
          .to be_between(issue.relative_position, issue1.relative_position).exclusive
      end

      it 'positions issue in the middle of other two if distance is big enough' do
        issue.update relative_position: 6000
        issue1.update relative_position: 10000

        new_issue.move_between(issue, issue1)

        expect(new_issue.relative_position)
          .to be_between(issue.relative_position, issue1.relative_position).exclusive
      end

      it 'positions issue closer to the middle if we are at the very top' do
        new_issue.move_between(nil, issue)

        expect(new_issue.relative_position).to eq(issue.relative_position - RelativePositioning::IDEAL_DISTANCE)
      end

      it 'positions issue closer to the middle if we are at the very bottom' do
        new_issue.move_between(issue1, nil)

        expect(new_issue.relative_position).to eq(issue1.relative_position + RelativePositioning::IDEAL_DISTANCE)
      end

      it 'positions issue in the middle of other two if distance is not big enough' do
        issue.update relative_position: 100
        issue1.update relative_position: 400

        new_issue.move_between(issue, issue1)

        expect(new_issue.relative_position).to eq(250)
      end

      it 'positions issue in the middle of other two is there is no place' do
        issue.update relative_position: 100
        issue1.update relative_position: 101

        new_issue.move_between(issue, issue1)
        [issue, issue1].each(&:reset)

        expect(new_issue.relative_position)
          .to be_between(issue.relative_position, issue1.relative_position).exclusive
      end

      it 'uses rebalancing if there is no place' do
        issue.update relative_position: 100
        issue1.update relative_position: 101
        issue2 = create(:issue, relative_position: 102, project: project)
        new_issue.update relative_position: 103

        new_issue.move_between(issue1, issue2)
        new_issue.save!
        [issue, issue1, issue2].each(&:reset)

        expect(new_issue.relative_position)
          .to be_between(issue1.relative_position, issue2.relative_position).exclusive

        expect([issue, issue1, issue2, new_issue].map(&:relative_position).uniq).to have_attributes(size: 4)
      end

      it 'positions issue right if we pass non-sequential parameters' do
        issue.update relative_position: 99
        issue1.update relative_position: 101
        issue2 = create(:issue, relative_position: 102, project: project)
        new_issue.update relative_position: 103

        new_issue.move_between(issue, issue2)
        new_issue.save!

        expect(new_issue.relative_position).to be(100)
      end
    end
  end

  context 'when an external authentication service' do
    before do
      enable_external_authorization_service_check
    end

    describe '#visible_to_user?' do
      it 'does not check the external webservice for auditors' do
        issue = build(:issue)
        user = build(:auditor)

        expect(::Gitlab::ExternalAuthorization).not_to receive(:access_allowed?)

        issue.visible_to_user?(user)
      end
    end
  end

  describe "#issue_link_type" do
    let(:issue) { build(:issue) }

    it 'returns nil for a regular issue' do
      expect(issue.issue_link_type).to be_nil
    end

    where(:id, :issue_link_source_id, :issue_link_type_value, :expected) do
      1 | 1   | 0 | 'relates_to'
      1 | 1   | 1 | 'blocks'
      1 | 2   | 3 | 'relates_to'
      1 | 2   | 1 | 'is_blocked_by'
      1 | 2   | 2 | 'blocks'
    end

    with_them do
      let(:issue) { build(:issue) }
      subject { issue.issue_link_type }

      before do
        allow(issue).to receive(:id).and_return(id)
        allow(issue).to receive(:issue_link_source_id).and_return(issue_link_source_id)
        allow(issue).to receive(:issue_link_type_value).and_return(issue_link_type_value)
      end

      it { is_expected.to eq(expected) }
    end
  end

  describe "#blocked_by_issues" do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project) }
    let_it_be(:issue) { create(:issue, project: project) }
    let_it_be(:blocking_issue) { create(:issue, project: project) }
    let_it_be(:other_project_blocking_issue) { create(:issue) }
    let_it_be(:blocked_by_issue) { create(:issue, project: project) }
    let_it_be(:confidential_blocked_by_issue) { create(:issue, :confidential, project: project) }
    let_it_be(:related_issue) { create(:issue, project: project) }
    let_it_be(:closed_blocking_issue) { create(:issue, project: project, state: :closed) }

    before_all do
      create(:issue_link, source: blocking_issue, target: issue, link_type: IssueLink::TYPE_BLOCKS)
      create(:issue_link, source: other_project_blocking_issue, target: issue, link_type: IssueLink::TYPE_BLOCKS)
      create(:issue_link, source: issue, target: blocked_by_issue, link_type: IssueLink::TYPE_IS_BLOCKED_BY)
      create(:issue_link, source: issue, target: confidential_blocked_by_issue, link_type: IssueLink::TYPE_IS_BLOCKED_BY)
      create(:issue_link, source: issue, target: related_issue, link_type: IssueLink::TYPE_RELATES_TO)
      create(:issue_link, source: closed_blocking_issue, target: issue, link_type: IssueLink::TYPE_BLOCKS)
    end

    context 'when user can read issues' do
      it 'returns blocked issues' do
        project.add_developer(user)
        other_project_blocking_issue.project.add_developer(user)

        expect(issue.blocked_by_issues(user)).to match_array([blocking_issue, blocked_by_issue, other_project_blocking_issue, confidential_blocked_by_issue])
      end
    end

    context 'when user cannot read issues' do
      it 'returns empty array' do
        expect(issue.blocked_by_issues(user)).to be_empty
      end
    end

    context 'when user can read some issues' do
      it 'returns issues that user can read' do
        guest = create(:user)
        project.add_guest(guest)

        expect(issue.blocked_by_issues(guest)).to match_array([blocking_issue, blocked_by_issue])
      end
    end
  end

  it_behaves_like 'having health status'

  describe '#can_assign_epic?' do
    let(:user)    { create(:user) }
    let(:group)   { create(:group) }
    let(:project) { create(:project, group: group) }
    let(:issue)   { create(:issue, project: project) }

    subject { issue.can_assign_epic?(user) }

    context 'when epics feature is available' do
      before do
        stub_licensed_features(epics: true)
      end

      context 'when a user is not a project member' do
        it 'returns false' do
          expect(subject).to be_falsey
        end
      end

      context 'when a user is a project member' do
        it 'returns false' do
          project.add_developer(user)

          expect(subject).to be_falsey
        end
      end

      context 'when a user is a group member' do
        it 'returns true' do
          group.add_developer(user)

          expect(subject).to be_truthy
        end
      end
    end

    context 'when epics feature is not available' do
      it 'returns false' do
        group.add_developer(user)

        expect(subject).to be_falsey
      end
    end

    describe '#update_blocking_issues_count' do
      it 'updates blocking issues count' do
        issue = create(:issue, project: project)
        blocked_issue_1 = create(:issue, project: project)
        blocked_issue_2 = create(:issue, project: project)
        blocked_issue_3 = create(:issue, project: project)
        create(:issue_link, source: issue, target: blocked_issue_1, link_type: IssueLink::TYPE_BLOCKS)
        create(:issue_link, source: blocked_issue_2, target: issue, link_type: IssueLink::TYPE_IS_BLOCKED_BY)
        create(:issue_link, source: issue, target: blocked_issue_3, link_type: IssueLink::TYPE_BLOCKS)
        # Set to 0 for proper testing, this is being set by IssueLink callbacks.
        issue.update(blocking_issues_count: 0)

        expect { issue.update_blocking_issues_count! }
          .to change { issue.blocking_issues_count }.from(0).to(3)
      end
    end
  end

  describe '#supports_iterations?' do
    let(:group) { build_stubbed(:group) }
    let(:project_with_group) { build_stubbed(:project, group: group) }

    where(:issuable_type, :project, :supports_iterations) do
      [
        [:issue, :project_with_group, true],
        [:incident, :project_with_group, false]
      ]
    end

    with_them do
      let(:issue) { build_stubbed(issuable_type, project: send(project)) }

      subject { issue.supports_iterations? }

      it { is_expected.to eq(supports_iterations) }
    end
  end
end
