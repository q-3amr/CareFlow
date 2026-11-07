// CareFlow Cloudflare Worker — Groq proxy (and future FCM sender)
// Deployment: careflow-proxy.qsya374.workers.dev
// Secrets (set via `wrangler secret put`):
//   GROQ_API_KEY          — Groq API key (server-side only, never in client)
//   FIREBASE_SERVICE_ACCOUNT (future) — careflow-2004 service-account JSON
//     for server-side FCM sending. NEVER put this in the Flutter app.

export default {
  async fetch(request, env) {
    // CORS preflight for the Flutter Android app (webview / browser builds).
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type",
        },
      });
    }

    const url = new URL(request.url);

    // --- Groq proxy (current) ---
    if (url.pathname === "/" || url.pathname === "/groq") {
      return handleGroq(request, env);
    }

    // --- FCM notify (future) ---
    // Client will POST { token, title, body, type } here.
    // Server signs JWT with FIREBASE_SERVICE_ACCOUNT secret and calls
    // https://fcm.googleapis.com/v1/projects/careflow-2004/messages:send
    // Implement once a new careflow-2004 service account is created.
    if (url.pathname === "/notify") {
      return new Response(
        JSON.stringify({
          error: "not_implemented",
          detail: "FCM sending not yet wired in Worker. Client stub is active.",
        }),
        { status: 501, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response("Not Found", { status: 404 });
  },
};

async function handleGroq(request, env) {
  const GROQ_API_KEY = env.GROQ_API_KEY;

  if (!GROQ_API_KEY) {
    return new Response("GROQ_API_KEY not configured", { status: 500 });
  }

  if (request.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  try {
    const requestBody = await request.json();

    const groqResponse = await fetch(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${GROQ_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(requestBody),
      }
    );

    return new Response(groqResponse.body, {
      status: groqResponse.status,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
      },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: "Proxy error", details: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}
