-- Verse notes, independent of favorite_verses — a row only exists while the
-- note text is non-empty; clearing it deletes the row (see
-- VerseNoteRepository.set).
create table if not exists public.verse_notes (
  user_id uuid not null references auth.users (id) on delete cascade,
  book_id text not null,
  chapter_number integer not null,
  verse_number integer not null,
  note text not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, book_id, chapter_number, verse_number)
);

create index if not exists verse_notes_user_id_idx on public.verse_notes (user_id);

alter table public.verse_notes enable row level security;

drop policy if exists "Users can read their own verse notes" on public.verse_notes;
create policy "Users can read their own verse notes"
  on public.verse_notes for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own verse notes" on public.verse_notes;
create policy "Users can insert their own verse notes"
  on public.verse_notes for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own verse notes" on public.verse_notes;
create policy "Users can update their own verse notes"
  on public.verse_notes for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own verse notes" on public.verse_notes;
create policy "Users can delete their own verse notes"
  on public.verse_notes for delete
  using (auth.uid() = user_id);
