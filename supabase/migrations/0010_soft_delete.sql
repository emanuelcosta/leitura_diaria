-- Soft delete ("tombstones") for the list-shaped synced tables. Deleting
-- used to remove the row; another device that still had the item then
-- pushed it back on its next sync, because the union merge couldn't tell
-- "deleted" from "not received yet". Now a delete sets deleted_at, and the
-- app's merge (applyDeletions) keeps the item deleted unless it was changed
-- after that. Idempotent.
alter table public.favorite_verses add column if not exists deleted_at timestamptz;
alter table public.verse_notes     add column if not exists deleted_at timestamptz;
alter table public.doubt_verses    add column if not exists deleted_at timestamptz;
