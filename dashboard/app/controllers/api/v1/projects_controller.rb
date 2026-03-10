class Api::V1::ProjectsController < Api::V1::BaseController
  before_action :set_project, only: [:show, :update]

  def next_available
    project = Project.next_available
    if project
      render json: project
    else
      render json: {project: nil}, status: :ok
    end
  end

  def next_critical
    project = Project.next_critical
    if project
      render json: project
    else
      render json: {project: nil}, status: :ok
    end
  end

  def waiting_with_replies
    projects = Project.waiting_with_replies.includes(:replies)
    render json: projects, include: [:replies]
  end

  def stale_pr_review
    projects = Project.stale_pr_review
    render json: projects
  end

  def human_pending_count
    render json: {
      count: Project.needs_human.count,
      limit: Project::MAX_HUMAN_PENDING,
      blocked: Project.needs_human.count >= Project::MAX_HUMAN_PENDING
    }
  end

  def show
    render json: @project
  end

  def create
    project = Project.new(project_params)
    if project.save
      project.activities.create!(action: "created", details: "Project created via API")
      render json: project, status: :created
    else
      render json: {errors: project.errors.full_messages}, status: :unprocessable_entity
    end
  end

  def update
    old_status = @project.status
    if @project.update(update_params)
      if @project.status != old_status
        AdminNotifier.status_changed(@project, old_status)
      end
      render json: @project
    else
      render json: {errors: @project.errors.full_messages}, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    permitted = params.require(:project).permit(
      :title, :description, :priority, :source,
      :honeybadger_fault_id, :honeybadger_project_key,
      :max_attempts, repos: [], file_urls: []
    )
    filter_blank_repos(permitted)
  end

  def update_params
    permitted = params.require(:project).permit(
      :title, :description, :priority, :status,
      :attempt_count, :waiting_since,
      repos: [], branches: {}, pr_urls: {}, file_urls: []
    )
    filter_blank_repos(permitted)
  end

  def filter_blank_repos(permitted)
    permitted[:repos] = permitted[:repos]&.reject(&:blank?) if permitted[:repos]
    permitted
  end
end
