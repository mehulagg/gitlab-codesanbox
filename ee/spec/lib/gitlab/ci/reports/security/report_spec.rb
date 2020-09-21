# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Reports::Security::Report do
  let_it_be(:pipeline) { create(:ci_pipeline) }

  let(:report) { described_class.new('sast', pipeline, created_at) }
  let(:created_at) { 2.weeks.ago }

  it { expect(report.type).to eq('sast') }

  describe '#add_scanner' do
    let(:scanner) { create(:ci_reports_security_scanner, external_id: 'find_sec_bugs') }

    subject { report.add_scanner(scanner) }

    it 'stores given scanner params in the map' do
      subject

      expect(report.scanners).to eq({ 'find_sec_bugs' => scanner })
    end

    it 'returns the added scanner' do
      expect(subject).to eq(scanner)
    end
  end

  describe '#add_identifier' do
    let(:identifier) { create(:ci_reports_security_identifier) }

    subject { report.add_identifier(identifier) }

    it 'stores given identifier params in the map' do
      subject

      expect(report.identifiers).to eq({ identifier.fingerprint => identifier })
    end

    it 'returns the added identifier' do
      expect(subject).to eq(identifier)
    end
  end

  describe '#add_finding' do
    let(:finding) { create(:ci_reports_security_finding) }

    it 'enriches given finding and stores it in the collection' do
      report.add_finding(finding)

      expect(report.findings).to eq([finding])
    end
  end

  describe '#clone_as_blank' do
    let(:report) do
      create(
        :ci_reports_security_report,
        findings: [create(:ci_reports_security_finding)],
        scanners: [create(:ci_reports_security_scanner)],
        identifiers: [create(:ci_reports_security_identifier)]
      )
    end

    it 'creates a blank report with copied type and pipeline' do
      clone = report.clone_as_blank

      expect(clone.type).to eq(report.type)
      expect(clone.pipeline).to eq(report.pipeline)
      expect(clone.created_at).to eq(report.created_at)
      expect(clone.findings).to eq([])
      expect(clone.scanners).to eq({})
      expect(clone.identifiers).to eq({})
    end
  end

  describe '#replace_with!' do
    let(:report) do
      create(
        :ci_reports_security_report,
        findings: [create(:ci_reports_security_finding)],
        scanners: [create(:ci_reports_security_scanner)],
        identifiers: [create(:ci_reports_security_identifier)]
      )
    end

    let(:other_report) do
      create(
        :ci_reports_security_report,
        findings: [create(:ci_reports_security_finding, compare_key: 'other_finding')],
        scanners: [create(:ci_reports_security_scanner, external_id: 'other_scanner', name: 'Other Scanner')],
        identifiers: [create(:ci_reports_security_identifier, external_id: 'other_id', name: 'other_scanner')]
      )
    end

    before do
      report.replace_with!(other_report)
    end

    it 'replaces report contents with other reports contents' do
      expect(report.findings).to eq(other_report.findings)
      expect(report.scanners).to eq(other_report.scanners)
      expect(report.identifiers).to eq(other_report.identifiers)
    end
  end

  describe '#merge!' do
    let(:merged_report) { double('Report') }

    before do
      merge_reports_service = double('MergeReportsService')

      allow(::Security::MergeReportsService).to receive(:new).and_return(merge_reports_service)
      allow(merge_reports_service).to receive(:execute).and_return(merged_report)
      allow(report).to receive(:replace_with!)
    end

    subject { report.merge!(described_class.new('sast', pipeline, created_at)) }

    it 'invokes the merge with other report and then replaces this report contents by merge result' do
      subject

      expect(report).to have_received(:replace_with!).with(merged_report)
    end
  end
end
