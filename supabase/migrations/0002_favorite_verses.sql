-- Favorited verses, synced from the app's local SQLite store. Not scoped to
-- a translation (ACF/ARC) — a favorite is a reference (book/chapter/verse),
-- shown in whichever translation the user currently has selected.
create table if not exists public.favorite_verses (
  user_id uuid not null references auth.users (id) on delete cascade,
  book_id text not null,
  chapter_number integer not null,
  verse_number integer not null,
  created_at timestamptz not null default now(),
  primary key (user_id, book_id, chapter_number, verse_number)
);

create index if not exists favorite_verses_user_id_idx on public.favorite_verses (user_id);

alter table public.favorite_verses enable row level security;

drop policy if exists "Users can read their own favorites" on public.favorite_verses;
create policy "Users can read their own favorites"
  on public.favorite_verses for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own favorites" on public.favorite_verses;
create policy "Users can insert their own favorites"
  on public.favorite_verses for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own favorites" on public.favorite_verses;
create policy "Users can delete their own favorites"
  on public.favorite_verses for delete
  using (auth.uid() = user_id);
