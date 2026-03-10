import { z } from "zod/v3";
import * as mailgun from "../lib/mailgun-client.js";
import * as dashboard from "../lib/dashboard-client.js";

export function register(server) {
  server.tool(
    "send_email",
    "Send an email to the project owner. Includes project ID in subject for reply tracking.",
    {
      project_id: z.number().describe("Project ID"),
      subject: z.string().describe("Email subject (project tag will be prepended)"),
      body: z.string().describe("Email body text")
    },
    async ({ project_id, subject, body }) => {
      const taggedSubject = `[Project #${project_id}] ${subject}`;
      await mailgun.sendEmail({ subject: taggedSubject, body });
      await dashboard.addActivity(project_id, "email_sent", `Subject: ${taggedSubject}`);
      return { content: [{ type: "text", text: `Email sent: "${taggedSubject}"` }] };
    }
  );
}
