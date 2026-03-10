class ReposController < ApplicationController
  before_action :set_repo, only: [:show, :edit, :update, :destroy, :retry_setup]

  def index
    @repos = Repo.order(:name)
  end

  def show
  end

  def new
    @repo = Repo.new
  end

  def create
    @repo = Repo.new(repo_params)
    if @repo.save
      redirect_to @repo, notice: "Repo added. Setup will run on next orchestrator cycle."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @repo.update(repo_params)
      redirect_to @repo, notice: "Repo updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @repo.destroy
    redirect_to repos_path, notice: "Repo deleted."
  end

  def retry_setup
    @repo.update!(setup_status: "pending", setup_log: nil)
    redirect_to @repo, notice: "Setup will retry on next orchestrator cycle."
  end

  private

  def set_repo
    @repo = Repo.find(params[:id])
  end

  def repo_params
    params.require(:repo).permit(:name, :github_url, :local_path, :ruby_version, :gemset, :framework, :test_command)
  end
end
