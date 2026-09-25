-- Real deletion: soft-deleted rows (deleted_at set, see 0010) only need to
-- live long enough for every device to learn about the deletion. After
-- 30 days they're removed for good. Keep this window in sync with
-- `deletionRetention` in lib/logic/sync_merge.dart (the app prunes its own
-- deletion records with the same rule). Idempotent.

create extension if not exists pg_cron;

-- A deleted doubt/note keeps only "which verse, when" — never its text.
update public.doubt_verses set note = null where deleted_at is not null and note is not null;
update public.verse_notes  set note = ''   where deleted_at is not null and note <> '';

-- pg_cron >= 1.4 replaces a job scheduled again under the same name, so
-- re-running this file updates the job instead of duplicating it.
-- Daily at 06:00 UTC (03:00 in Brasília).
select cron.schedule(
  'purge-sync-deletions',
  '0 6 * * *',
  $$
    delete from public.favorite_verses where deleted_at < now() - interval '30 days';
    delete from public.verse_notes     where deleted_at < now() - interval '30 days';
    delete from public.doubt_verses    where deleted_at < now() - interval '30 days';
  $$
);
