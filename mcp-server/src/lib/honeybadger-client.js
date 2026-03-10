const HONEYBADGER_AUTH_TOKEN = process.env.HONEYBADGER_AUTH_TOKEN;
const HONEYBADGER_API_URL = "https://app.honeybadger.io/v2";

async function request(method, path, body = null) {
  const options = {
    method,
    headers: {
      "Authorization": `Basic ${Buffer.from(`${HONEYBADGER_AUTH_TOKEN}:`).toString("base64")}`,
      "Content-Type": "application/json",
      "Accept": "application/json"
    }
  };

  if (body) {
    options.body = JSON.stringify(body);
  }

  const response = await fetch(`${HONEYBADGER_API_URL}${path}`, options);

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Honeybadger API ${method} ${path} failed (${response.status}): ${text}`);
  }

  return response.json();
}

export async function getFaults(projectId, { resolved = false } = {}) {
  const params = new URLSearchParams();
  if (!resolved) params.append("q", "-is:resolved");
  return request("GET", `/projects/${projectId}/faults?${params}`);
}

export async function getFault(projectId, faultId) {
  return request("GET", `/projects/${projectId}/faults/${faultId}`);
}

export async function resolveFault(projectId, faultId) {
  return request("PUT", `/projects/${projectId}/faults/${faultId}/resolve`);
}
