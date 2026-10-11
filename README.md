# sbl.gg

A forum for science-based lifting, where lifters argue about the evidence with the researchers who did the studies. Live at https://sbl.gg.

## How it works

- **The whole site is `index.html`**: plain HTML, CSS and JavaScript, with no build step and no frameworks.
- **Posts live in a Supabase database** (project `SBL-site`). The page talks to it with the *publishable* key that's in `index.html`. That key is meant to be public: database rules decide what it can do.
- **Hosting is Netlify.** It's connected to this GitHub repo, so every push to `main` goes live at sbl.gg within about a minute. Pushing any other branch gives a preview address instead.

## Change the site

1. Edit `index.html`. Ask Claude Code or Codex for what you want ("make the header green", "add a Supplements channel").
2. Check it locally: `python3 -m http.server 8000`, then open http://localhost:8000. It uses the real database, so any post you make there is real.
3. `git add -A && git commit -m "what changed" && git push`. It goes live automatically.
4. If something breaks: in Netlify, open **Deploys**, pick the last good one, and click **Publish deploy**.

## Moderate

Go to Supabase → **Table Editor** → `threads` or `replies`. Tick **hidden** on a row to take it off the site, or delete the row. Pinned posts and News posts can only be made here, not from the site: add a row with `pinned` = true, or `channel` = `news`.

## What visitors can and can't do (database rules, `supabase/schema.sql`)

- They can read visible threads and replies, start threads in General, Hypertrophy, Nutrition or Experts, and reply to any visible thread.
- They can't edit or delete anything, can't pin, and can't post in News.
- Titles are capped at 140 characters, posts at 6000, and names at 60.

## Changing the database

Adding a channel, a field or a table means changing the database as well as `index.html`:
- New channel: add it to `CHANNELS` in `index.html` **and** to the `channel in (...)` list in `supabase/schema.sql`. Then run that change in Supabase → **SQL Editor**.
- Keep `supabase/schema.sql` up to date with what's actually in the database.
- The database password is in a private note (ask Dad). It goes in a local `.env` file, which git ignores, **never** in this repo.

## Accounts

Domain: Porkbun (sbl.gg, sbl.life). Hosting: Netlify (team SBL). Database: Supabase (org SBL, project SBL-site). Code: GitHub.
