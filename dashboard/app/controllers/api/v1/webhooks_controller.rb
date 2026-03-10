class Api::V1::WebhooksController < ActionController::API
  before_action :verify_mailgun_signature, only: [:mailgun]
  before_action :verify_github_signature, only: [:github]

  def mailgun
    project_id = extract_project_id(params[:subject])

    unless project_id
      render json: {error: "No project ID found in subject"}, status: :ok
      return
    end

    project = Project.find_by(id: project_id)
    unless project
      render json: {error: "Project not found"}, status: :ok
      return
    end

    project.replies.create!(
      channel: :email,
      from_address: params[:sender] || params[:from],
      body: params["stripped-text"] || params["body-plain"] || "",
      received_at: Time.current,
      read: false
    )

    if project.waiting_input?
      project.activities.create!(action: "reply_received", details: "Email reply received")
    end

    render json: {received: true}, status: :ok
  end

  def github
    event = request.headers["X-GitHub-Event"]
    body = request.body.read
    request.body.rewind
    payload = JSON.parse(body)

    pr_url = extract_pr_url(event, payload)
    unless pr_url
      render json: {ignored: true}, status: :ok
      return
    end

    project = Project.find_by_pr_url(pr_url)
    unless project
      render json: {error: "No matching project"}, status: :ok
      return
    end

    reply_attrs = build_github_reply(event, payload)
    unless reply_attrs
      render json: {ignored: true}, status: :ok
      return
    end

    project.replies.create!(reply_attrs.merge(channel: :github, received_at: Time.current, read: false))

    if project.pr_review? || project.staging?
      old_status = project.status
      project.waiting_input!
      project.activities.create!(action: "status_changed", details: "Status changed from #{old_status} to waiting_input via GitHub #{event}")
    end

    render json: {received: true}, status: :ok
  end

  def twilio
    from = params[:From]
    body = params[:Body] || ""

    project = find_recent_sms_project
    if project
      project.replies.create!(
        channel: :sms,
        from_address: from,
        body: body,
        received_at: Time.current,
        read: false
      )

      if project.waiting_input?
        project.activities.create!(action: "reply_received", details: "SMS reply received")
      end
    end

    render xml: "<Response></Response>", content_type: "text/xml"
  end

  private

  def extract_project_id(subject)
    return nil if subject.blank?
    match = subject.match(/\[Project #(\d+)\]/)
    match ? match[1].to_i : nil
  end

  def find_recent_sms_project
    Activity.where(action: "sms_sent")
      .where("created_at > ?", 24.hours.ago)
      .order(created_at: :desc)
      .first&.project
  end

  def extract_pr_url(event, payload)
    case event
    when "pull_request_review"
      payload.dig("pull_request", "html_url")
    when "pull_request_review_comment"
      payload.dig("pull_request", "html_url")
    when "issue_comment"
      # Only handle comments on PRs (they have a pull_request key)
      payload.dig("issue", "pull_request", "html_url") if payload.dig("issue", "pull_request")
    end
  end

  def build_github_reply(event, payload)
    case event
    when "pull_request_review"
      review = payload["review"] || {}
      body = [review["state"]&.humanize, review["body"]].compact_blank.join(": ")
      return nil if body.blank?
      {from_address: review.dig("user", "login") || "unknown", body: body}
    when "pull_request_review_comment"
      comment = payload["comment"] || {}
      path = comment["path"]
      line = comment["line"] || comment["original_line"]
      body = [comment["body"], path && "File: #{path}:#{line}"].compact_blank.join("\n")
      return nil if body.blank?
      {from_address: comment.dig("user", "login") || "unknown", body: body}
    when "issue_comment"
      comment = payload["comment"] || {}
      return nil if comment["body"].blank?
      {from_address: comment.dig("user", "login") || "unknown", body: comment["body"]}
    end
  end

  def verify_github_signature
    secret = ENV.fetch("GITHUB_WEBHOOK_SECRET", "")
    return if secret.blank?

    signature = request.headers["X-Hub-Signature-256"].to_s
    body = request.body.read
    request.body.rewind

    expected = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, body)
    unless ActiveSupport::SecurityUtils.secure_compare(expected, signature)
      render json: {error: "Invalid signature"}, status: :unauthorized
    end
  end

  def verify_mailgun_signature
    token = params[:token]
    timestamp = params[:timestamp]
    signature = params[:signature]
    api_key = ENV.fetch("MAILGUN_WEBHOOK_SIGNING_KEY", "")

    return if api_key.blank?

    digest = OpenSSL::HMAC.hexdigest("SHA256", api_key, "#{timestamp}#{token}")
    unless ActiveSupport::SecurityUtils.secure_compare(digest, signature.to_s)
      render json: {error: "Invalid signature"}, status: :unauthorized
    end
  end
end
