import { z } from "zod/v3";
import * as hb from "../lib/honeybadger-client.js";
import * as dashboard from "../lib/dashboard-client.js";

// Map your Honeybadger project IDs to repo names and display names.
// Set HONEYBADGER_PROJECT_MAP env var as JSON, e.g.:
//   {"12345": {"repo": "my-app", "name": "My App"}}
const PROJECT_MAP = JSON.parse(process.env.HONEYBADGER_PROJECT_MAP || "{}");

export function register(server) {
  server.tool(
    "get_honeybadger_faults",
    "Get unresolved faults from a Honeybadger project",
    {
      honeybadger_project_id: z.string().describe("Honeybadger project ID")
    },
    async ({ honeybadger_project_id }) => {
      const result = await hb.getFaults(honeybadger_project_id);
      return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    }
  );

  server.tool(
    "get_honeybadger_fault_detail",
    "Get details of a specific Honeybadger fault",
    {
      honeybadger_project_id: z.string().describe("Honeybadger project ID"),
      fault_id: z.string().describe("Fault ID")
    },
    async ({ honeybadger_project_id, fault_id }) => {
      const result = await hb.getFault(honeybadger_project_id, fault_id);
      return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    }
  );

  server.tool(
    "resolve_honeybadger_fault",
    "Mark a Honeybadger fault as resolved",
    {
      honeybadger_project_id: z.string().describe("Honeybadger project ID"),
      fault_id: z.string().describe("Fault ID")
    },
    async ({ honeybadger_project_id, fault_id }) => {
      await hb.resolveFault(honeybadger_project_id, fault_id);
      return { content: [{ type: "text", text: `Fault ${fault_id} resolved.` }] };
    }
  );

  server.tool(
    "create_project_from_fault",
    "Create a dashboard project from a Honeybadger fault (for auto-queue from orchestrator)",
    {
      honeybadger_project_id: z.string().describe("Honeybadger project ID"),
      fault_id: z.string().describe("Fault ID")
    },
    async ({ honeybadger_project_id, fault_id }) => {
      const fault = await hb.getFault(honeybadger_project_id, fault_id);
      const mapping = PROJECT_MAP[honeybadger_project_id] || { repo: "unknown", name: "Unknown" };

      const project = await dashboard.createProject({
        title: `BUGFIX: ${fault.klass} — ${fault.message}`,
        description: [
          `**Honeybadger Fault** #${fault.id} in ${mapping.name}`,
          `**Class**: ${fault.klass}`,
          `**Message**: ${fault.message}`,
          `**Environment**: ${fault.environment}`,
          `**Occurrences**: ${fault.notices_count}`,
          `**Component**: ${fault.component || "N/A"}`,
          `**Action**: ${fault.action || "N/A"}`,
          "",
          "Fix this bug in the codebase. Check the Honeybadger fault detail for the full backtrace."
        ].join("\n"),
        priority: "low",
        source: "honeybadger",
        honeybadger_fault_id: String(fault.id),
        honeybadger_project_key: honeybadger_project_id,
        repos: [mapping.repo]
      });

      return { content: [{ type: "text", text: JSON.stringify(project, null, 2) }] };
    }
  );
}
