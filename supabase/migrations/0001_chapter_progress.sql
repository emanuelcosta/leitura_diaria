-- Per-user reading progress, synced from the app's local SQLite store.
-- The book/chapter catalog itself stays static in assets/reading_plan.json
-- and is not duplicated here; only read state travels to Supabase.
create table if not exists public.chapter_progress (
  user_id uuid not null references auth.users (id) on delete cascade,
  book_id text not null,
  chapter_number integer not null,
  is_read boolean not null default false,
  read_at timestamptz,
  note text,
  updated_at timestamptz not null default now(),
  primary key (user_id, book_id, chapter_number)
);

create index if not exists chapter_progress_user_id_idx on public.chapter_progress (user_id);

alter table public.chapter_progress enable row level security;

-- `create policy` has no `if not exists`, so drop-then-create to keep this
-- file safe to re-run.
drop policy if exists "Users can read their own progress" on public.chapter_progress;
create policy "Users can read their own progress"
  on public.chapter_progress for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own progress" on public.chapter_progress;
create policy "Users can insert their own progress"
  on public.chapter_progress for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own progress" on public.chapter_progress;
create policy "Users can update their own progress"
  on public.chapter_progress for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own progress" on public.chapter_progress;
create policy "Users can delete their own progress"
  on public.chapter_progress for delete
  using (auth.uid() = user_id);
