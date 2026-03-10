import { z } from "zod/v3";
import * as dashboard from "../lib/dashboard-client.js";

const DEPLOY_WEBHOOKS = {
  erp: process.env.HATCHBOX_ERP_WEBHOOK,
  commportal: process.env.HATCHBOX_COMMPORTAL_WEBHOOK
};

export function register(server) {
  server.tool(
    "deploy_staging",
    "Trigger a staging deploy on Hatchbox for erp or commportal",
    {
      project_id: z.number().describe("Dashboard project ID (for activity logging)"),
      app: z.enum(["erp", "commportal"]).describe("Which app to deploy"),
      sha: z.string().optional().describe("Specific commit SHA to deploy (defaults to latest)")
    },
    async ({ project_id, app, sha }) => {
      const webhookUrl = DEPLOY_WEBHOOKS[app];
      const params = new URLSearchParams();
      if (sha) {
        params.append("sha", sha);
      } else {
        params.append("latest", "true");
      }

      const response = await fetch(`${webhookUrl}?${params}`, { method: "POST" });

      if (!response.ok) {
        const text = await response.text();
        throw new Error(`Hatchbox deploy webhook failed (${response.status}): ${text}`);
      }

      await dashboard.addActivity(project_id, "staging_deploy", `Deployed ${app}${sha ? ` at ${sha}` : " (latest)"}`);
      return { content: [{ type: "text", text: `Deploy triggered for ${app}${sha ? ` at ${sha}` : " (latest)"}` }] };
    }
  );
}
