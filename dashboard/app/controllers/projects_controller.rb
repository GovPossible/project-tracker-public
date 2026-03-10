class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :edit, :update, :destroy, :add_reply, :nudge]

  PER_PAGE = 20

  def index
    @projects = if params[:status].present?
      Project.where(status: params[:status])
    else
      Project.active
    end

    @query = params[:q].presence
    if @query
      sanitized = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      @projects = @projects.where("title ILIKE ? OR description ILIKE ?", sanitized, sanitized)
    end

    @projects = @projects.order(priority: :asc, created_at: :desc)

    total = @projects.count
    @page = [params[:page].to_i, 1].max
    @total_pages = [(total / PER_PAGE.to_f).ceil, 1].max
    @page = @total_pages if @page > @total_pages
    @projects = @projects.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
  end

  def show
    @activities = @project.activities.recent
    @replies = @project.replies.recent
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)
    if @project.save
      @project.activities.create!(action: "created", details: "Project created via dashboard")
      redirect_to @project, notice: "Project created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    old_status = @project.status
    if @project.update(project_params)
      if @project.status != old_status
        @project.activities.create!(action: "status_changed", details: "Status changed from #{old_status} to #{@project.status} via dashboard")
      end
      redirect_to @project, notice: "Project updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def add_reply
    image_urls = Array(params[:image_urls]).reject(&:blank?)
    @project.replies.create!(
      channel: :dashboard,
      from_address: "Admin (dashboard)",
      body: params[:body].presence,
      image_urls: image_urls,
      received_at: Time.current,
      read: false
    )

    if @project.pr_review? || @project.staging?
      old_status = @project.status
      @project.waiting_input!
      @project.activities.create!(action: "status_changed", details: "Status changed from #{old_status} to waiting_input via dashboard comment")
    end

    redirect_to @project, notice: "Comment added."
  end

  def nudge
    @project.replies.create!(
      channel: :dashboard,
      from_address: "Admin (dashboard)",
      body: "Please continue working on this.",
      received_at: Time.current,
      read: false
    )

    redirect_to @project, notice: "Agent nudged."
  end

  def destroy
    @project.destroy
    redirect_to projects_path, notice: "Project deleted."
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    permitted = params.require(:project).permit(:title, :description, :priority, :source, :status, :max_attempts, repos: [], file_urls: [])
    permitted[:repos] = permitted[:repos]&.reject(&:blank?) if permitted[:repos]
    permitted[:file_urls] = permitted[:file_urls]&.reject(&:blank?) if permitted[:file_urls]
    permitted
  end
end
