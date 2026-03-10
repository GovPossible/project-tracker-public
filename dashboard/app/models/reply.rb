class Reply < ApplicationRecord
  belongs_to :project

  enum :channel, {email: 0, sms: 1, dashboard: 2, github: 3}

  validates :channel, presence: true
  validates :received_at, presence: true
  validate :body_or_images_present

  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc, id: :desc) }

  def mark_read!
    update!(read: true)
  end

  private

  def body_or_images_present
    if body.blank? && image_urls.blank?
      errors.add(:base, "must include a body or at least one image")
    end
  end
end
