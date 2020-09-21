# frozen_string_literal: true

module QA
  module EE
    module Page
      module Component
        module LicenseManagement
          extend QA::Page::PageConcern

          def self.prepended(base)
            super

            base.class_eval do
              view 'app/assets/javascripts/reports/components/report_item.vue' do
                element :report_item_row
              end

              view 'app/assets/javascripts/reports/components/issue_status_icon.vue' do
                element :icon_status, ':data-qa-selector="`status_${status}_icon`" ' # rubocop:disable QA/ElementWithPattern
              end

              view 'ee/app/assets/javascripts/vue_shared/license_compliance/components/set_approval_status_modal.vue' do
                element :license_management_modal
                element :approve_license_button
                element :deny_license_button
              end

              view 'ee/app/assets/javascripts/vue_shared/license_compliance/mr_widget_license_report.vue' do
                element :license_report_widget
              end
            end
          end

          def has_approved_license?(name)
            within_element(:report_item_row, text: name) do
              has_element?(:status_success_icon, wait: 1)
            end
          end

          def has_denied_license?(name)
            within_element(:report_item_row, text: name) do
              has_element?(:status_failed_icon, wait: 1)
            end
          end

          def click_license(name)
            within_element(:license_report_widget) do
              click_on name
            end
            wait_for_animated_element(:license_management_modal)
          end

          def approve_license(name)
            wait_until(reload: true) do
              click_license(name)
              has_element?(:approve_license_button, wait: 1)
            end
            click_element(:approve_license_button)
          end

          def deny_license(name)
            wait_until(reload: true) do
              click_license(name)
              has_element?(:deny_license_button, wait: 1)
            end
            click_element(:deny_license_button)
          end
        end
      end
    end
  end
end
