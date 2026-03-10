const DASHBOARD_URL = process.env.DASHBOARD_URL || "http://localhost:3000";
const API_KEY = process.env.DASHBOARD_API_KEY;

async function request(method, path, body = null) {
  const url = `${DASHBOARD_URL}/api/v1${path}`;
  const options = {
    method,
    headers: {
      "Authorization": `Bearer ${API_KEY}`,
      "Content-Type": "application/json",
      "Accept": "application/json"
    }
  };

  if (body) {
    options.body = JSON.stringify(body);
  }

  const response = await fetch(url, options);

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Dashboard API ${method} ${path} failed (${response.status}): ${text}`);
  }

  return response.json();
}

export async function getProject(id) {
  return request("GET", `/projects/${id}`);
}

export async function getNextAvailable() {
  return request("GET", "/projects/next_available");
}

export async function getWaitingWithReplies() {
  return request("GET", "/projects/waiting_with_replies");
}

export async function createProject(params) {
  return request("POST", "/projects", { project: params });
}

export async function updateProject(id, params) {
  return request("PATCH", `/projects/${id}`, { project: params });
}

export async function addActivity(projectId, action, details) {
  return request("POST", `/projects/${projectId}/activities`, { activity: { action, details } });
}

export async function getReplies(projectId) {
  return request("GET", `/projects/${projectId}/replies`);
}

export async function createReply(projectId, params) {
  return request("POST", `/projects/${projectId}/replies`, { reply: params });
}

export async function markRepliesRead(projectId) {
  return request("PATCH", `/projects/${projectId}/replies/mark_read`);
}
