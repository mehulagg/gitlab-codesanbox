# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/licenses/_info' do
  context 'when observing the license' do
    before do
      assign(:license, license)
    end

    context 'when plan can be upgraded' do
      let(:license) { create(:license, plan: License::STARTER_PLAN) }

      it 'shows "How to upgrade" link' do
        render

        expect(rendered).to have_content('Plan: Starter - How to upgrade')
        expect(rendered).to have_link('How to upgrade')
      end
    end

    context 'when plan can not be upgraded' do
      let(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

      it 'does not show "How to upgrade" link' do
        render

        expect(rendered).to have_content('Plan: Ultimate')
        expect(rendered).not_to have_link('How to upgrade')
      end
    end
  end
end
