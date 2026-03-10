import { z } from "zod/v3";
import * as twilio from "../lib/twilio-client.js";
import * as dashboard from "../lib/dashboard-client.js";

export function register(server) {
  server.tool(
    "send_sms",
    "Send an SMS to the project owner",
    {
      project_id: z.number().describe("Project ID"),
      message: z.string().describe("SMS message text (keep short)")
    },
    async ({ project_id, message }) => {
      const tagged = `[Project #${project_id}] ${message}`;
      await twilio.sendSms({ message: tagged });
      await dashboard.addActivity(project_id, "sms_sent", `Message: ${tagged}`);
      return { content: [{ type: "text", text: `SMS sent: "${tagged}"` }] };
    }
  );
}
