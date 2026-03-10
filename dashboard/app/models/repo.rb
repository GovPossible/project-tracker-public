class Repo < ApplicationRecord
  SETUP_STATUSES = %w[pending setting_up ready failed].freeze

  validates :name, presence: true, uniqueness: true
  validates :github_url, presence: true
  validates :setup_status, inclusion: {in: SETUP_STATUSES}

  scope :ready, -> { where(setup_status: "ready") }
  scope :pending_setup, -> { where(setup_status: %w[pending failed]) }

  def pending?
    setup_status == "pending"
  end

  def ready?
    setup_status == "ready"
  end

  def failed?
    setup_status == "failed"
  end

  def setting_up?
    setup_status == "setting_up"
  end
end
