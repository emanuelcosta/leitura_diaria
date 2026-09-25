-- Each favorite now carries its own marker color (color-coded study
-- highlights) plus updated_at, so a color change on one device wins over the
-- older color on another (newest wins, see mergeFavorites). Existing rows
-- become amber, the single color used until then. Idempotent.
alter table public.favorite_verses add column if not exists color text not null default 'amber';
alter table public.favorite_verses add column if not exists updated_at timestamptz;
update public.favorite_verses set updated_at = created_at where updated_at is null;
alter table public.favorite_verses alter column updated_at set default now();
alter table public.favorite_verses alter column updated_at set not null;
