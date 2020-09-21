# frozen_string_literal: true

class Profiles::BillingsController < Profiles::ApplicationController
  before_action :verify_namespace_plan_check_enabled

  def index
    @plans_data = FetchSubscriptionPlansService
      .new(plan: current_user.namespace.plan_name_for_upgrading)
      .execute
    track_experiment_event(:contact_sales_btn_in_app, 'page_view:billing_plans:profile')
    record_experiment_user(:contact_sales_btn_in_app)
  end
end
