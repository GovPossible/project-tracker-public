class Activity < ApplicationRecord
  belongs_to :project

  validates :action, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
