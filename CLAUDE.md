# Instructions for AI coding agents (Claude Code, Codex)

Read README.md first. Key rules:

- The site is a single file, `index.html`. Keep it that way: no frameworks, no build step, no npm. Netlify serves the repo root as-is.
- Data goes through the Supabase REST API (`SB_URL`, `SB_KEY` at the top of the STORAGE section). `SB_KEY` is the publishable key, which is fine to have in public code. **Never** put the database password, a `sb_secret_...` key or a `service_role` key in any file in this repo. If a task seems to need one, stop and tell the user. Schema changes go in `supabase/schema.sql` and are run by hand in the Supabase SQL Editor.
- Visitors can only `select` and `insert` (row-level security). Don't write code that needs update or delete from the browser; moderation is done in the Supabase dashboard.
- Always escape user text with `esc()` before putting it in HTML. Never insert user content with raw innerHTML.
- Adding a channel means touching both `CHANNELS` in `index.html` and the `channel in (...)` check in `supabase/schema.sql`.
- Test locally with `python3 -m http.server 8000` before pushing. Pushing to `main` deploys to the live site at sbl.gg.
- Keep Bowie's design: navy header, channel board with colored stripes, featured debate, recent threads.
