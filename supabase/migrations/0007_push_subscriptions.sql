-- Um FCM token por usuário (linha única, como reading_bookmarks) — guarda
-- horário/fuso do lembrete diário pra que a Edge Function
-- send-daily-reminders saiba quando e pra quem disparar o push.
create table if not exists public.push_subscriptions (
  user_id uuid primary key references auth.users (id) on delete cascade,
  fcm_token text not null,
  platform text not null,
  reminder_hour integer not null,
  reminder_minute integer not null,
  timezone text not null,
  updated_at timestamptz not null default now()
);

alter table public.push_subscriptions enable row level security;

drop policy if exists "Users can read their own push subscription" on public.push_subscriptions;
create policy "Users can read their own push subscription"
  on public.push_subscriptions for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own push subscription" on public.push_subscriptions;
create policy "Users can insert their own push subscription"
  on public.push_subscriptions for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own push subscription" on public.push_subscriptions;
create policy "Users can update their own push subscription"
  on public.push_subscriptions for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own push subscription" on public.push_subscriptions;
create policy "Users can delete their own push subscription"
  on public.push_subscriptions for delete
  using (auth.uid() = user_id);

-- A Edge Function send-daily-reminders usa a service role key (bypassa
-- RLS) pra ler todo mundo e decidir quem está no horário. pg_cron chama a
-- função via HTTP a cada minuto; a service role key fica no Vault (setup
-- manual pelo SQL Editor do Supabase, não versionado — ver docs).
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- cron.schedule() upserts by job name (pg_cron >= 1.4), so re-running this
-- migration just updates the existing job instead of erroring.
select cron.schedule(
  'send-daily-reminders-every-minute',
  '* * * * *',
  $$
  select net.http_post(
    url := 'https://szgtwzltwlylcgtwhlvx.supabase.co/functions/v1/send-daily-reminders',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || (
        select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key'
      ),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
