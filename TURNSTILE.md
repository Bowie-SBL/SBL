# Step 2: switching on the "are you human" check (Cloudflare Turnstile)

Ready on the `turnstile` branch, **not live**. Turn it on when bots start getting through the step-1 database guard (`supabase/guard.sql`): repeated spam, or the flood breaker tripping more than once.

What changes: every post goes through a small Netlify function (`netlify/functions/post.mjs`, served at `/api/post`). It asks Cloudflare whether the visitor is human, then saves the post with a server-only key. Visitors lose the ability to write to the database directly. Real users mostly see nothing; occasionally a small "Verify you are human" box.

## Turn it on (about 15 minutes)

1. **Cloudflare account (free)**: https://dash.cloudflare.com/sign-up, then **Turnstile → Add widget**. Name it `sbl`, hostnames `sbl.gg` and `localhost`, mode **Managed**. You get a **site key** (public) and a **secret key** (private).
2. **Supabase secret key**: Supabase → Project Settings → **API Keys** → Secret keys → copy the `sb_secret_...` key.
3. **Netlify environment variables**: Project configuration → **Environment variables** → add
   `TURNSTILE_SECRET` = Turnstile secret key, and `SUPABASE_SECRET_KEY` = the `sb_secret_...` key.
4. In `index.html` on this branch, set `const TURNSTILE_SITEKEY = "<site key>";` (the site key is public, so it's fine in the code).
5. Merge: `git checkout main && git merge turnstile && git push`. Wait for the deploy, then post a test on sbl.gg. The check box should appear, and the post should go through.
6. Lock the back door: run `supabase/turnstile_on.sql` in Supabase → SQL Editor.
7. Test again: a post from the site works, and a direct API post (bots) gets "permission denied".

## Turn it off

Run `supabase/turnstile_off.sql`, then set `TURNSTILE_SITEKEY = ""` and push. The site posts directly again.
