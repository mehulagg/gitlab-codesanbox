# frozen_string_literal: true

class Projects::ConfluencesController < Projects::ApplicationController
  before_action :ensure_confluence

  def show
  end

  private

  def ensure_confluence
    render_404 unless project.has_confluence?
  end
end
