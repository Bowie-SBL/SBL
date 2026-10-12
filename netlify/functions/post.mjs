// Step 2 spam defence: every post goes through this Netlify function, which checks
// Cloudflare Turnstile ("are you human") before saving anything. Visitors can no longer
// write to the database directly (turnstile_on.sql removes that permission).
//
// Netlify environment variables (Project configuration > Environment variables):
//   TURNSTILE_SECRET     the Turnstile widget's secret key (Cloudflare dashboard)
//   SUPABASE_SECRET_KEY  a Supabase secret key (sb_secret_...), Supabase > Project Settings > API Keys
// Never put either value in this repo.

const SB_URL = "https://hwtlwayufhevegidecuz.supabase.co/rest/v1";

const json = (status, obj) =>
  new Response(JSON.stringify(obj), { status, headers: { "Content-Type": "application/json" } });

export default async (req, context) => {
  if (req.method !== "POST") return json(405, { error: "POST only" });
  let p;
  try { p = await req.json(); } catch { return json(400, { error: "Bad request." }); }
  const ip = context.ip || req.headers.get("x-nf-client-connection-ip") || "";

  // 1. Is this a human?
  const form = new URLSearchParams({ secret: process.env.TURNSTILE_SECRET || "", response: p.token || "", remoteip: ip });
  const ts = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", { method: "POST", body: form })
    .then(r => r.json()).catch(() => ({ success: false }));
  if (!ts.success) return json(403, { error: "Couldn't confirm you're human. Refresh the page and try again." });

  // 2. Save it. The database's own guard (guard.sql) still applies: rate limits, link hold,
  //    duplicates, flood breaker. The visitor's IP is passed so per-person limits still work.
  let table, row;
  // The secret key bypasses the database's row rules, so re-check what visitors may do here.
  const OPEN_CHANNELS = ["general", "hypertrophy", "nutrition", "experts"];   // not "news"
  if (p.kind === "thread" && !OPEN_CHANNELS.includes(p.channel)) return json(400, { error: "Bad request." });
  if (p.kind === "thread") { table = "threads"; row = { channel: p.channel, title: p.title, body: p.body, name: p.name }; }
  else if (p.kind === "reply") { table = "replies"; row = { thread_id: p.thread_id, body: p.body, name: p.name }; }
  else return json(400, { error: "Bad request." });

  const key = process.env.SUPABASE_SECRET_KEY || "";
  const r = await fetch(`${SB_URL}/${table}?select=id`, {
    method: "POST",
    headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json",
               Prefer: "return=representation", "x-sbl-client-ip": ip },
    body: JSON.stringify(row),
  });
  const out = await r.json().catch(() => ({}));
  if (!r.ok) {
    const msg = (out && out.message) || "";
    return json(400, { error: msg.startsWith("SBL: ") ? msg.slice(5) : "Couldn't post. Try again." });
  }
  return json(200, { rows: out });   // [] means the database held it for review
};

export const config = { path: "/api/post" };
