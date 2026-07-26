-- Saved fits: a private bookmark list, one row per (user, fit).
--
-- Deliberately not a "like": nobody but the saver can read the list, and no
-- count is exposed anywhere, so this never turns into a vanity metric. The
-- arena's only public signal stays the win record.
--
-- Rows are kept even after the fit is retired or hidden, so the saved grid can
-- explain where a fit went instead of silently losing it. The extra select
-- policy on `fits` below is what makes that row readable to the saver.

create table if not exists public.saved_fits (
  user_id uuid not null references public.profiles(id) on delete cascade,
  fit_id uuid not null references public.fits(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, fit_id)
);

-- The saved grid: one user's saves, newest first.
create index if not exists saved_fits_user_created_idx
on public.saved_fits (user_id, created_at desc);

alter table public.saved_fits enable row level security;

drop policy if exists "Users can read their own saves" on public.saved_fits;

create policy "Users can read their own saves"
on public.saved_fits
for select
to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "Users can save fits for themselves" on public.saved_fits;

create policy "Users can save fits for themselves"
on public.saved_fits
for insert
to authenticated
with check (user_id = (select auth.uid()));

drop policy if exists "Users can remove their own saves" on public.saved_fits;

create policy "Users can remove their own saves"
on public.saved_fits
for delete
to authenticated
using (user_id = (select auth.uid()));

revoke insert, update, delete on public.saved_fits from authenticated;

grant select, delete on public.saved_fits to authenticated;
-- created_at is left to the default: a client-supplied timestamp would let the
-- grid's ordering be forged.
grant insert (user_id, fit_id) on public.saved_fits to authenticated;

-- A fit the user saved stays readable to them after its owner retires it or
-- moderation hides it, so the saved grid can show a "retired" tile rather than
-- dropping the fit without explanation. Permissive policies OR together, so
-- this only widens reads for rows the user has personally saved.
drop policy if exists "Saved fits stay readable to the user who saved them"
on public.fits;

create policy "Saved fits stay readable to the user who saved them"
on public.fits
for select
to authenticated
using (
  exists (
    select 1
    from public.saved_fits s
    where s.fit_id = fits.id
      and s.user_id = (select auth.uid())
  )
);
