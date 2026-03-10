class Api::V1::RepliesController < Api::V1::BaseController
  before_action :set_project

  def index
    replies = @project.replies.unread.recent
    render json: replies
  end

  def create
    reply = @project.replies.new(reply_params)
    if reply.save
      AdminNotifier.reply_received(reply) unless reply.from_address&.include?("Admin")
      render json: reply, status: :created
    else
      render json: {errors: reply.errors.full_messages}, status: :unprocessable_entity
    end
  end

  def mark_read
    @project.replies.unread.update_all(read: true)
    render json: {marked_read: true}
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def reply_params
    params.require(:reply).permit(:channel, :from_address, :body, :received_at, image_urls: [])
  end
end
