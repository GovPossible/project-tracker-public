const MAILGUN_API_KEY = process.env.MAILGUN_API_KEY;
const MAILGUN_DOMAIN = process.env.MAILGUN_DOMAIN;
const MAILGUN_FROM = process.env.MAILGUN_FROM;
const MAILGUN_TO = process.env.MAILGUN_TO;
const MAILGUN_API_URL = `https://api.mailgun.net/v3/${MAILGUN_DOMAIN}`;

export async function sendEmail({ subject, body, to = MAILGUN_TO }) {
  const form = new URLSearchParams();
  form.append("from", `Project Agent <${MAILGUN_FROM}>`);
  form.append("to", to);
  form.append("subject", subject);
  form.append("text", body);

  const response = await fetch(`${MAILGUN_API_URL}/messages`, {
    method: "POST",
    headers: {
      "Authorization": `Basic ${Buffer.from(`api:${MAILGUN_API_KEY}`).toString("base64")}`
    },
    body: form
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Mailgun send failed (${response.status}): ${text}`);
  }

  return response.json();
}
