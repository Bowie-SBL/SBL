-- sbl.gg spam guard (step 1). Applied 11 Oct 2026. Run after schema.sql.
--
-- Every post that comes in through the website passes through sbl_guard() first:
--   * posting paused (site_settings.posting_open = false) -> rejected with a message
--   * same person (IP) posting > 5 times in 10 minutes      -> rejected ("posting too fast")
--   * same person posting the exact same text within a day -> rejected ("already posted")
--   * site-wide flood (> flood_limit posts in 10 minutes)  -> posting is switched OFF
--     automatically and the post is held
--   * contains a link                                      -> held for review, not shown
-- Held posts go to held_posts (invisible to visitors). To publish one, run in the
-- Supabase SQL Editor:   select approve_held(<id>);
-- To reopen posting after a flood:   update site_settings set posting_open = true;
-- Posts added by hand in the Supabase dashboard skip all of this.
-- IPs are stored only as a salted hash (ip_hash), never in the clear.

create table if not exists public.site_settings (
  id           int primary key default 1 check (id = 1),
  posting_open boolean not null default true,
  flood_limit  int not null default 40,     -- posts per 10 minutes, whole site
  per_ip_limit int not null default 5,      -- posts per 10 minutes, one person
  note         text,
  updated      timestamptz not null default now()
);
insert into public.site_settings (id) values (1) on conflict do nothing;

create table if not exists public.held_posts (
  id         bigint generated always as identity primary key,
  kind       text not null check (kind in ('thread','reply')),
  channel    text,
  title      text,
  thread_id  bigint,
  body       text not null,
  name       text not null,
  ip_hash    text,
  reason     text not null,          -- 'link' | 'flood'
  created    timestamptz not null default now(),
  decided    text                    -- null = waiting; 'approved' | 'rejected'
);

alter table public.threads add column if not exists ip_hash text;
alter table public.replies add column if not exists ip_hash text;
create index if not exists threads_ip_created on public.threads(ip_hash, created);
create index if not exists replies_ip_created on public.replies(ip_hash, created);
create index if not exists held_ip_created   on public.held_posts(ip_hash, created);

alter table public.site_settings enable row level security;
alter table public.held_posts    enable row level security;
revoke all on public.site_settings, public.held_posts from anon, authenticated;
drop policy if exists "read posting state" on public.site_settings;
create policy "read posting state" on public.site_settings for select to anon, authenticated using (true);
grant select (posting_open) on public.site_settings to anon, authenticated;

-- visitors may read posts but not the ip_hash column
revoke select on public.threads, public.replies from anon, authenticated;
grant select (id, channel, title, body, name, pinned, key, hidden, created) on public.threads to anon, authenticated;
grant select (id, thread_id, body, name, hidden, created) on public.replies to anon, authenticated;

create or replace function public.sbl_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  hdr      text := current_setting('request.headers', true);
  ip       text;
  h        text;
  s        site_settings;
  n_ip     int;
  n_all    int;
  txt      text;
  is_thread boolean := (tg_table_name = 'threads');
  j        jsonb := to_jsonb(new);   -- generic access: replies have no title/channel
begin
  -- only guard posts arriving through the public API (dashboard / SQL edits pass)
  if hdr is null or hdr = '' then return new; end if;

  ip := coalesce(nullif(hdr::json->>'cf-connecting-ip',''),
                 split_part(coalesce(hdr::json->>'x-forwarded-for',''), ',', 1));
  h  := md5('sbl-salt-2026:' || coalesce(ip,'unknown'));
  new.ip_hash := h;
  select * into s from site_settings where id = 1;

  if not s.posting_open then
    raise exception 'SBL: Posting is paused for a little while. Please try again later.';
  end if;

  select (select count(*) from threads    where ip_hash = h and created > now() - interval '10 minutes')
       + (select count(*) from replies    where ip_hash = h and created > now() - interval '10 minutes')
       + (select count(*) from held_posts where ip_hash = h and created > now() - interval '10 minutes')
    into n_ip;
  if n_ip >= s.per_ip_limit then
    raise exception 'SBL: You''re posting too fast. Wait a few minutes and try again.';
  end if;

  if exists (select 1 from threads where ip_hash = h and body = new.body and created > now() - interval '1 day')
  or exists (select 1 from replies where ip_hash = h and body = new.body and created > now() - interval '1 day') then
    raise exception 'SBL: You already posted that.';
  end if;

  select (select count(*) from threads    where created > now() - interval '10 minutes')
       + (select count(*) from replies    where created > now() - interval '10 minutes')
       + (select count(*) from held_posts where created > now() - interval '10 minutes')
    into n_all;
  if n_all >= s.flood_limit then
    update site_settings set posting_open = false, note = 'auto: flood at ' || now(), updated = now() where id = 1;
    insert into held_posts(kind, channel, title, thread_id, body, name, ip_hash, reason)
      values (case when is_thread then 'thread' else 'reply' end,
              j->>'channel', j->>'title', (j->>'thread_id')::bigint, new.body, new.name, h, 'flood');
    return null;   -- nothing published; posting is now switched off
  end if;

  txt := coalesce(j->>'title', '') || ' ' || new.body || ' ' || new.name;
  if txt ~* '(https?://|www\.|\m[a-z0-9-]+\.(com|net|org|ru|cn|xyz|io|co|shop|top|info|biz|site|online|store|link|click|me|ly)\M)' then
    insert into held_posts(kind, channel, title, thread_id, body, name, ip_hash, reason)
      values (case when is_thread then 'thread' else 'reply' end,
              j->>'channel', j->>'title', (j->>'thread_id')::bigint, new.body, new.name, h, 'link');
    return null;   -- held for review
  end if;

  return new;
end $$;

drop trigger if exists sbl_guard_threads on public.threads;
create trigger sbl_guard_threads before insert on public.threads for each row execute function public.sbl_guard();
drop trigger if exists sbl_guard_replies on public.replies;
create trigger sbl_guard_replies before insert on public.replies for each row execute function public.sbl_guard();

-- Publish a held post (run as the database owner, e.g. in the SQL Editor).
create or replace function public.approve_held(held_id bigint) returns text
language plpgsql security definer set search_path = public as $$
declare p held_posts;
begin
  select * into p from held_posts where id = held_id and decided is null;
  if not found then return 'no such waiting post'; end if;
  if p.kind = 'thread' then
    insert into threads(channel, title, body, name, ip_hash, created) values (p.channel, p.title, p.body, p.name, p.ip_hash, p.created);
  else
    insert into replies(thread_id, body, name, ip_hash, created) values (p.thread_id, p.body, p.name, p.ip_hash, p.created);
  end if;
  update held_posts set decided = 'approved' where id = held_id;
  return 'published';
end $$;
revoke all on function public.approve_held(bigint) from public, anon, authenticated;
revoke all on function public.sbl_guard() from public, anon, authenticated;
