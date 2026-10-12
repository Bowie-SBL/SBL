-- Step 2 ON: visitors can no longer write to the database directly; every post must go
-- through the Netlify function /api/post, which checks Cloudflare Turnstile first.
-- Run in Supabase > SQL Editor AFTER the turnstile branch is live with TURNSTILE_SITEKEY set
-- and both Netlify environment variables in place (see TURNSTILE.md).
revoke insert on public.threads, public.replies from anon, authenticated;
