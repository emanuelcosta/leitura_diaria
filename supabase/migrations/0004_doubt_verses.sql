-- Verses marked "tenho dúvida" (want to research/understand later).
-- Independent of favorite_verses — same shape, different meaning.
create table if not exists public.doubt_verses (
  user_id uuid not null references auth.users (id) on delete cascade,
  book_id text not null,
  chapter_number integer not null,
  verse_number integer not null,
  created_at timestamptz not null default now(),
  primary key (user_id, book_id, chapter_number, verse_number)
);

create index if not exists doubt_verses_user_id_idx on public.doubt_verses (user_id);

alter table public.doubt_verses enable row level security;

drop policy if exists "Users can read their own doubts" on public.doubt_verses;
create policy "Users can read their own doubts"
  on public.doubt_verses for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own doubts" on public.doubt_verses;
create policy "Users can insert their own doubts"
  on public.doubt_verses for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own doubts" on public.doubt_verses;
create policy "Users can delete their own doubts"
  on public.doubt_verses for delete
  using (auth.uid() = user_id);
