class DashboardController < ApplicationController
  def show
    @status_counts = Project.group(:status).count
    @recent_activities = Activity.includes(:project).recent.limit(15)
    @waiting_projects = Project.waiting_input.includes(:replies).select { |p|
      last_reply = p.replies.recent.first
      last_reply && !last_reply.from_address&.include?("Admin")
    }
  end
end
