const TWILIO_ACCOUNT_SID = process.env.TWILIO_ACCOUNT_SID;
const TWILIO_AUTH_TOKEN = process.env.TWILIO_AUTH_TOKEN;
const TWILIO_FROM = process.env.TWILIO_FROM || "+18446242712";
const TWILIO_TO = process.env.TWILIO_TO || "+18034136198";
const TWILIO_API_URL = `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}`;

export async function sendSms({ message, to = TWILIO_TO }) {
  const form = new URLSearchParams();
  form.append("From", TWILIO_FROM);
  form.append("To", to);
  form.append("Body", message);

  const response = await fetch(`${TWILIO_API_URL}/Messages.json`, {
    method: "POST",
    headers: {
      "Authorization": `Basic ${Buffer.from(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`).toString("base64")}`
    },
    body: form
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Twilio send failed (${response.status}): ${text}`);
  }

  return response.json();
}
