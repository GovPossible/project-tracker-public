class Project < ApplicationRecord
  MAX_HUMAN_PENDING = 5

  has_many :activities, dependent: :destroy
  has_many :replies, dependent: :destroy

  enum :status, {queued: 0, working: 1, waiting_input: 2, pr_review: 3, staging: 4, done: 5, failed: 6}
  enum :priority, {critical: 0, high: 1, normal: 2, low: 3}
  enum :source, {manual: 0, honeybadger: 1}

  validates :title, presence: true
  validates :status, presence: true
  validates :priority, presence: true
  validates :source, presence: true
  validates :attempt_count, numericality: {greater_than_or_equal_to: 0}
  validates :max_attempts, numericality: {greater_than: 0}
  validates :honeybadger_fault_id, uniqueness: true, allow_nil: true

  scope :active, -> { where.not(status: [:done, :failed]) }
  scope :queued_by_priority, -> { queued.order(priority: :asc, created_at: :asc) }
  scope :waiting_with_replies, -> { where(status: [:waiting_input, :pr_review, :working]).joins(:replies).where(replies: {read: false}).distinct.order(priority: :asc, created_at: :asc) }
  scope :needs_human, -> { where(status: [:waiting_input, :staging]) }
  def self.stale_pr_review
    pr_review.where("updated_at < ?", 45.minutes.ago).order(priority: :asc, created_at: :asc).reject(&:has_unread_replies?)
  end

  def self.find_by_pr_url(url)
    where.not(pr_urls: "{}").find_each do |project|
      return project if project.pr_urls.values.include?(url)
    end
    nil
  end

  def self.next_available
    queued_by_priority.first
  end

  def self.next_critical
    # Critical projects that are actionable: queued, waiting with unread replies, or stale PR review
    candidates = critical.where.not(status: [:done, :failed])

    # Queued critical
    queued_candidate = candidates.queued.order(created_at: :asc).first

    # Waiting with unread replies
    reply_candidate = candidates.where(status: [:waiting_input, :pr_review, :working])
      .joins(:replies).where(replies: {read: false}).distinct.order(created_at: :asc).first

    # Stale PR review
    stale_candidate = candidates.pr_review.where("updated_at < ?", 45.minutes.ago)
      .order(created_at: :asc).reject(&:has_unread_replies?).first

    [queued_candidate, reply_candidate, stale_candidate].compact.min_by(&:created_at)
  end

  def increment_attempt!
    increment!(:attempt_count)
    if attempt_count >= max_attempts
      failed!
      activities.create!(action: "failed", details: "Max attempts (#{max_attempts}) reached")
    end
  end

  def max_attempts_reached?
    attempt_count >= max_attempts
  end

  def has_unread_replies?
    replies.where(read: false).exists?
  end

end
