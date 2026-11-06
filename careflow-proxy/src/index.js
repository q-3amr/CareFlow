export default {
  async fetch(request, env) {
    const GROQ_API_KEY = env.GROQ_API_KEY; // Access the secret environment variable

    if (!GROQ_API_KEY) {
      return new Response("GROQ_API_KEY not configured", { status: 500 });
    }

    // Ensure it's a POST request and has a body
    if (request.method !== 'POST') {
      return new Response("Method Not Allowed", { status: 405 });
    }

    try {
      const requestBody = await request.json();

      // Forward request to Groq API
      const groqResponse = await fetch("https://api.groq.com/openai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${GROQ_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(requestBody),
      });

      // Return Groq API's response directly
      return new Response(groqResponse.body, {
        status: groqResponse.status,
        headers: {
          "Content-Type": "application/json",
          // Add CORS headers to allow your Flutter web app to access it
          "Access-Control-Allow-Origin": "*", // IMPORTANT: For production, narrow this to your Firebase Hosting domain
          "Access-Control-Allow-Methods": "POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type",
        },
      });

    } catch (error) {
      return new Response(JSON.stringify({ error: "Proxy error", details: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
  },
};