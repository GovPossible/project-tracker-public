import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

import * as projectTools from "./tools/project.js";
import * as emailTools from "./tools/email.js";
import * as smsTools from "./tools/sms.js";
import * as honeybadgerTools from "./tools/honeybadger.js";
import * as hatchboxTools from "./tools/hatchbox.js";

const server = new McpServer({
  name: "project-tracker-agent",
  version: "1.0.0"
});

projectTools.register(server);
emailTools.register(server);
smsTools.register(server);
honeybadgerTools.register(server);
hatchboxTools.register(server);

const transport = new StdioServerTransport();
await server.connect(transport);
