module ApplicationHelper
  STATUS_COLORS = {
    "queued" => "bg-gray-100 text-gray-800",
    "working" => "bg-blue-100 text-blue-800",
    "waiting_input" => "bg-yellow-100 text-yellow-800",
    "pr_review" => "bg-purple-100 text-purple-800",
    "staging" => "bg-indigo-100 text-indigo-800",
    "done" => "bg-green-100 text-green-800",
    "failed" => "bg-red-100 text-red-800"
  }.freeze

  PRIORITY_COLORS = {
    "critical" => "bg-red-100 text-red-700",
    "high" => "bg-orange-100 text-orange-700",
    "normal" => "bg-gray-100 text-gray-700",
    "low" => "bg-gray-50 text-gray-500"
  }.freeze

  def status_badge(status)
    css = STATUS_COLORS.fetch(status, "bg-gray-100 text-gray-800")
    tag.span status.humanize, class: "inline-block px-2 py-0.5 rounded-full text-xs font-medium #{css}"
  end

  def priority_badge(priority)
    css = PRIORITY_COLORS.fetch(priority, "bg-gray-100 text-gray-700")
    tag.span priority.humanize, class: "inline-block px-2 py-0.5 rounded-full text-xs font-medium #{css}"
  end

  CHANNEL_COLORS = {
    "email" => "bg-blue-100 text-blue-700",
    "sms" => "bg-green-100 text-green-700",
    "dashboard" => "bg-purple-100 text-purple-700",
    "github" => "bg-gray-800 text-white"
  }.freeze

  def channel_badge_class(channel)
    CHANNEL_COLORS.fetch(channel, "bg-gray-100 text-gray-700")
  end

  def waiting_on_badge(project)
    return unless project.waiting_input?
    last_reply = project.replies.recent.first
    if last_reply.nil? || last_reply.from_address&.include?("Admin")
      tag.span "Waiting on agent", class: "inline-block px-2 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-700"
    else
      tag.span "Waiting on you", class: "inline-block px-2 py-0.5 rounded-full text-xs font-medium bg-orange-100 text-orange-700"
    end
  end

  def render_markdown(text)
    return "" if text.blank?
    # Ensure blank line before list items so Redcarpet recognizes them as lists
    normalized = text.gsub(/([^\n])\n([ \t]*(?:[-*+]|\d+\.) )/, "\\1\n\n\\2")
    renderer = Redcarpet::Render::HTML.new(hard_wrap: true, filter_html: true)
    markdown = Redcarpet::Markdown.new(renderer, autolink: true, tables: true, fenced_code_blocks: true)
    sanitize(markdown.render(normalized))
  end
end
