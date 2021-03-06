# frozen_string_literal: true

module Vulnerabilities
  class ProjectsGrade
    attr_reader :vulnerable, :grade, :project_ids

    # project_ids can contain IDs from projects that do not belong to vulnerable, they will be filtered out in `projects` method
    def initialize(vulnerable, letter_grade, project_ids = [])
      @vulnerable = vulnerable
      @grade = letter_grade
      @project_ids = project_ids
    end

    delegate :count, to: :projects

    def projects
      return vulnerable.projects.none if project_ids.blank?

      vulnerable.projects.with_vulnerability_statistics.inc_routes.where(id: project_ids)
    end

    def self.grades_for(vulnerables)
      ::Vulnerabilities::Statistic
        .for_project(vulnerables.map(&:projects).reduce(&:or))
        .group(:letter_grade)
        .select(:letter_grade, 'array_agg(project_id) project_ids')
        .then do |statistics|
          vulnerables.each_with_object({}) do |vulnerable, hash|
            hash[vulnerable] = statistics.map { |statistic| new(vulnerable, statistic.letter_grade, statistic.project_ids) }
          end
        end
    end
  end
end
