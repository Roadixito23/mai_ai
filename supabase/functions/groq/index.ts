// Proxy de Groq para Mai. La key de Groq vive en los secrets de Supabase y
// solo la usa quien tenga una sesión válida del proyecto (el dueño: los
// registros públicos están desactivados).
//
// Despliegue (ver README):
//   supabase secrets set GROQ_API_KEY=gsk_...
//   supabase functions deploy groq --no-verify-jwt
//
// `--no-verify-jwt` porque la sesión se verifica aquí, con Supabase Auth.
// Opcional: el secret OWNER_USER_ID limita el acceso a ese usuario.

import { createClient } from "jsr:@supabase/supabase-js@2";

const GROQ = "https://api.groq.com/openai/v1";

/// Rutas de Groq que Mai puede usar a través del proxy.
const ALLOWED = new Set(["chat/completions", "models", "audio/transcriptions"]);

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

function error(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: { message } }), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

const auth = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_ANON_KEY")!,
).auth;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  if (!token) return error(401, "Falta la sesión.");

  const { data, error: authError } = await auth.getUser(token);
  if (authError || !data.user) return error(401, "Sesión inválida o expirada.");

  const owner = Deno.env.get("OWNER_USER_ID");
  if (owner && data.user.id !== owner) return error(403, "Este usuario no puede usar Mai.");

  // /groq/chat/completions o /functions/v1/groq/chat/completions -> chat/completions
  const path = new URL(req.url).pathname.replace(/^.*?\/groq\/?/, "");
  if (!ALLOWED.has(path)) return error(404, `Ruta no permitida: ${path}`);

  const key = Deno.env.get("GROQ_API_KEY");
  if (!key) return error(500, "Falta el secret GROQ_API_KEY en Supabase.");

  const headers = new Headers({ Authorization: `Bearer ${key}` });
  const contentType = req.headers.get("Content-Type");
  if (contentType) headers.set("Content-Type", contentType);

  const upstream = await fetch(`${GROQ}/${path}`, {
    method: req.method,
    headers,
    body: req.method === "GET" ? undefined : req.body,
  });

  // Un 401 de Groq es la key del servidor, no la sesión del usuario.
  if (upstream.status === 401) {
    return error(502, "La key de Groq guardada en Supabase no es válida o expiró.");
  }

  // El cuerpo pasa tal cual, así el streaming (SSE) llega en vivo.
  return new Response(upstream.body, {
    status: upstream.status,
    headers: {
      ...CORS,
      "Content-Type": upstream.headers.get("Content-Type") ?? "application/json",
    },
  });
});
