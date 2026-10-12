-- Step 2 OFF: let visitors post straight to the database again (the step-1 guard still applies).
grant insert (channel, title, body, name) on public.threads to anon, authenticated;
grant insert (thread_id, body, name) on public.replies to anon, authenticated;
