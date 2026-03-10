import { z } from "zod/v3";
import * as dashboard from "../lib/dashboard-client.js";
import * as mailgun from "../lib/mailgun-client.js";

export function register(server) {
  server.tool(
    "get_current_project",
    "Get the current project details by ID (passed via PROJECT_ID env var or argument)",
    { project_id: z.number().optional().describe("Project ID. Defaults to PROJECT_ID env var.") },
    async ({ project_id }) => {
      const id = project_id || parseInt(process.env.PROJECT_ID);
      if (!id) return { content: [{ type: "text", text: "No project_id provided and PROJECT_ID env var not set." }], isError: true };
      const project = await dashboard.getProject(id);
      return { content: [{ type: "text", text: JSON.stringify(project, null, 2) }] };
    }
  );

  server.tool(
    "update_project_status",
    "Update the status of a project and log the change",
    {
      project_id: z.number().describe("Project ID"),
      status: z.enum(["queued", "working", "waiting_input", "pr_review", "staging", "done", "failed"]).describe("New status"),
      details: z.string().optional().describe("Details about the status change")
    },
    async ({ project_id, status, details }) => {
      const params = { status };
      if (status === "waiting_input") params.waiting_since = new Date().toISOString();
      await dashboard.updateProject(project_id, params);
      await dashboard.addActivity(project_id, `status_changed_to_${status}`, details || `Status changed to ${status}`);
      return { content: [{ type: "text", text: `Project ${project_id} status updated to ${status}` }] };
    }
  );

  server.tool(
    "add_activity_log",
    "Log an activity on a project",
    {
      project_id: z.number().describe("Project ID"),
      action: z.string().describe("Action name (e.g., commit, test_passed, question_asked)"),
      details: z.string().optional().describe("Additional details")
    },
    async ({ project_id, action, details }) => {
      const activity = await dashboard.addActivity(project_id, action, details || "");
      return { content: [{ type: "text", text: JSON.stringify(activity, null, 2) }] };
    }
  );

  server.tool(
    "set_project_branches",
    "Record branch names, PR URLs, and/or target repos on a project",
    {
      project_id: z.number().describe("Project ID"),
      repos: z.array(z.string()).optional().describe("Target repo names (e.g. ['erp', 'commportal-v2'])"),
      branches: z.record(z.string()).optional().describe("Map of repo name to branch name"),
      pr_urls: z.record(z.string()).optional().describe("Map of repo name to PR URL")
    },
    async ({ project_id, repos, branches, pr_urls }) => {
      const params = {};
      if (repos) params.repos = repos;
      if (branches) params.branches = branches;
      if (pr_urls) params.pr_urls = pr_urls;
      await dashboard.updateProject(project_id, params);
      return { content: [{ type: "text", text: `Project ${project_id} updated` }] };
    }
  );

  server.tool(
    "check_replies",
    "Check for unread replies on a project and mark them as read",
    { project_id: z.number().describe("Project ID") },
    async ({ project_id }) => {
      const replies = await dashboard.getReplies(project_id);
      if (replies.length > 0) {
        await dashboard.markRepliesRead(project_id);
      }
      return { content: [{ type: "text", text: replies.length > 0 ? JSON.stringify(replies, null, 2) : "No unread replies." }] };
    }
  );

  server.tool(
    "reply_to_feedback",
    "Reply to the project owner's feedback on a project. Creates a dashboard reply and sends an email notification.",
    {
      project_id: z.number().describe("Project ID"),
      body: z.string().describe("Your response to the project owner's feedback"),
      summary: z.string().optional().describe("Short summary for email notification (defaults to first 200 chars of body)")
    },
    async ({ project_id, body, summary }) => {
      await dashboard.createReply(project_id, {
        channel: "dashboard",
        from_address: "Agent",
        body,
        received_at: new Date().toISOString(),
        read: false
      });

      const emailSummary = summary || (body.length > 200 ? body.substring(0, 200) + "..." : body);
      const dashboardUrl = process.env.DASHBOARD_URL || "http://localhost:3000";
      const projectUrl = `${dashboardUrl}/projects/${project_id}`;
      await mailgun.sendEmail({
        subject: `[Project #${project_id}] Agent replied to your feedback`,
        body: `${emailSummary}\n\nView full reply: ${projectUrl}`
      });

      await dashboard.addActivity(project_id, "replied_to_feedback", summary || body.substring(0, 200));
      return { content: [{ type: "text", text: `Reply posted and the project owner notified via email.` }] };
    }
  );

  server.tool(
    "get_next_project",
    "Get the next available queued project (highest priority first)",
    {},
    async () => {
      const result = await dashboard.getNextAvailable();
      if (!result || result.project === null) {
        return { content: [{ type: "text", text: "No projects in queue." }] };
      }
      return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    }
  );

  server.tool(
    "get_waiting_projects",
    "Get projects in waiting_input status that have unread replies",
    {},
    async () => {
      const projects = await dashboard.getWaitingWithReplies();
      return { content: [{ type: "text", text: JSON.stringify(projects, null, 2) }] };
    }
  );
}
