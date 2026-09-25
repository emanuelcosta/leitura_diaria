-- favorite_verses and doubt_verses were created without an UPDATE policy.
-- The app writes with `upsert`, which becomes an UPDATE when the row already
-- exists — so re-pushing an existing favorite/doubt (sync merge, "Sincronizar
-- agora", editing a doubt's note) was rejected by RLS.
drop policy if exists "Users can update their own favorites" on public.favorite_verses;
create policy "Users can update their own favorites"
  on public.favorite_verses for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own doubts" on public.doubt_verses;
create policy "Users can update their own doubts"
  on public.doubt_verses for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
