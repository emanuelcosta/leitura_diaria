-- Optional note on a doubt: what the user was thinking when they marked it.
alter table public.doubt_verses add column if not exists note text;
