class AdminNotifier
  MAILGUN_API_KEY = ENV["MAILGUN_API_KEY"]
  MAILGUN_DOMAIN = ENV["MAILGUN_DOMAIN"]
  FROM = "Agent <agent@#{MAILGUN_DOMAIN}>"
  TO = ENV["NOTIFICATION_EMAIL"]

  def self.notify(subject:, body:)
    return if MAILGUN_API_KEY.blank?

    uri = URI("https://api.mailgun.net/v3/#{MAILGUN_DOMAIN}/messages")
    req = Net::HTTP::Post.new(uri)
    req.basic_auth("api", MAILGUN_API_KEY)
    req.set_form_data(from: FROM, to: TO, subject: subject, text: body)

    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(req)
    end
  rescue => e
    Rails.logger.error("[AdminNotifier] Failed to send email: #{e.message}")
  end

  def self.project_url(project)
    "#{ENV.fetch("DASHBOARD_URL", "http://localhost:3000")}/projects/#{project.id}"
  end

  def self.reply_received(reply)
    project = reply.project
    notify(
      subject: "[Project ##{project.id}] Agent replied — #{project.title}",
      body: "#{reply.body[0, 500]}\n\nView project: #{project_url(project)}"
    )
  end

  def self.status_changed(project, old_status)
    case project.status
    when "waiting_input"
      notify(
        subject: "[Project ##{project.id}] Agent needs your input — #{project.title}",
        body: "Project moved from #{old_status} to waiting_input.\n\nView project: #{project_url(project)}"
      )
    when "staging"
      notify(
        subject: "[Project ##{project.id}] PR ready for review — #{project.title}",
        body: "The agent has finished and the PR is ready for your review.\n\nView project: #{project_url(project)}"
      )
    when "failed"
      notify(
        subject: "[Project ##{project.id}] Project failed — #{project.title}",
        body: "The project has been marked as failed.\n\nView project: #{project_url(project)}"
      )
    end
  end
end
