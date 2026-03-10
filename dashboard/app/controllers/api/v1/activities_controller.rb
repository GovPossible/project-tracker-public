class Api::V1::ActivitiesController < Api::V1::BaseController
  before_action :set_project

  def create
    activity = @project.activities.new(activity_params)
    if activity.save
      render json: activity, status: :created
    else
      render json: {errors: activity.errors.full_messages}, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def activity_params
    params.require(:activity).permit(:action, :details)
  end
end
