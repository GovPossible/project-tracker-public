class Api::V1::ReposController < Api::V1::BaseController
  before_action :set_repo, only: [:show, :update]

  def index
    repos = Repo.order(:name)
    render json: repos
  end

  def show
    render json: @repo
  end

  def pending_setup
    repos = Repo.pending_setup
    render json: repos
  end

  def update
    if @repo.update(repo_params)
      render json: @repo
    else
      render json: {errors: @repo.errors.full_messages}, status: :unprocessable_entity
    end
  end

  private

  def set_repo
    @repo = Repo.find(params[:id])
  end

  def repo_params
    params.require(:repo).permit(:setup_status, :setup_log, :local_path)
  end
end
