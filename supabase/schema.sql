-- sbl.gg forum schema (Supabase project SBL-site). Applied 11 Oct 2026.
-- Visitors (anon key) may READ visible posts and ADD new ones. Nobody can edit
-- or delete through the site. Moderation: in the Supabase Table Editor set
-- hidden = true on a row (it disappears from the site), or delete the row.

create table if not exists public.threads (
  id         bigint generated always as identity primary key,
  channel    text not null check (channel in ('news','general','hypertrophy','nutrition','experts')),
  title      text not null check (char_length(title) between 1 and 140),
  body       text not null check (char_length(body) between 1 and 6000),
  name       text not null default 'Anonymous' check (char_length(name) between 1 and 60),
  pinned     boolean not null default false,
  key        text unique,            -- fixed handle, e.g. 'preworkout' for the featured debate
  hidden     boolean not null default false,
  created    timestamptz not null default now()
);

create table if not exists public.replies (
  id         bigint generated always as identity primary key,
  thread_id  bigint not null references public.threads(id) on delete cascade,
  body       text not null check (char_length(body) between 1 and 6000),
  name       text not null default 'Anonymous' check (char_length(name) between 1 and 60),
  hidden     boolean not null default false,
  created    timestamptz not null default now()
);
create index if not exists replies_thread_idx on public.replies(thread_id);

alter table public.threads enable row level security;
alter table public.replies enable row level security;

drop policy if exists "read visible threads" on public.threads;
create policy "read visible threads" on public.threads for select to anon, authenticated using (not hidden);
drop policy if exists "post threads" on public.threads;
create policy "post threads" on public.threads for insert to anon, authenticated
  with check (not hidden and not pinned and key is null and channel <> 'news');

drop policy if exists "read visible replies" on public.replies;
create policy "read visible replies" on public.replies for select to anon, authenticated using (not hidden);
drop policy if exists "post replies" on public.replies;
create policy "post replies" on public.replies for insert to anon, authenticated
  with check (not hidden and exists (select 1 from public.threads t where t.id = thread_id and not t.hidden));

revoke all on public.threads, public.replies from anon, authenticated;
grant select on public.threads, public.replies to anon, authenticated;
grant insert (channel, title, body, name) on public.threads to anon, authenticated;
grant insert (thread_id, body, name) on public.replies to anon, authenticated;
