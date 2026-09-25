-- Doubts get updated_at, bumped when the comment is edited, so the newest
-- comment wins across devices (mergeDoubts). Before, "local wins" let a
-- device holding a stale comment overwrite an edit made elsewhere.
-- Backfilled from created_at. Idempotent.
alter table public.doubt_verses add column if not exists updated_at timestamptz;
update public.doubt_verses set updated_at = created_at where updated_at is null;
alter table public.doubt_verses alter column updated_at set default now();
alter table public.doubt_verses alter column updated_at set not null;
