-- "Continuar de onde parei" — a single row per user (unlike favorite/doubt
-- verses, which are many rows). Saving a new bookmark upserts over the old
-- one, same as the local SharedPreferences copy in BookmarkRepository.
create table if not exists public.reading_bookmarks (
  user_id uuid primary key references auth.users (id) on delete cascade,
  book_id text not null,
  book_order integer not null,
  book_name text not null,
  chapter_number integer not null,
  verse_number integer,
  saved_at timestamptz not null default now()
);

alter table public.reading_bookmarks enable row level security;

drop policy if exists "Users can read their own bookmark" on public.reading_bookmarks;
create policy "Users can read their own bookmark"
  on public.reading_bookmarks for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own bookmark" on public.reading_bookmarks;
create policy "Users can insert their own bookmark"
  on public.reading_bookmarks for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own bookmark" on public.reading_bookmarks;
create policy "Users can update their own bookmark"
  on public.reading_bookmarks for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own bookmark" on public.reading_bookmarks;
create policy "Users can delete their own bookmark"
  on public.reading_bookmarks for delete
  using (auth.uid() = user_id);
