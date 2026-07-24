-- Fits: one outfit photo entered into the arena.
--
-- wins/losses are denormalized counters maintained by cast_vote() rather than
-- aggregated from votes on every read, because the arena and the profile grid
-- both display them constantly.
--
-- A fit is matchable when it is neither soft-deleted by its owner
-- (deleted_at) nor pulled by moderation (hidden_at).

create table if not exists public.fits (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  -- Storage object path inside the public `fits` bucket, always prefixed with
  -- the owner's uuid: "<owner_id>/<unique-file-name>".
  image_path text not null,
  wins integer not null default 0 check (wins >= 0),
  losses integer not null default 0 check (losses >= 0),
  battles integer generated always as (wins + losses) stored,
  report_count integer not null default 0 check (report_count >= 0),
  hidden_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Matchmaking scans only live fits, so keep the index partial and small.
create index if not exists fits_matchable_idx
on public.fits (id)
where deleted_at is null and hidden_at is null;

-- Profile grid: a user's fits, newest first.
create index if not exists fits_owner_created_idx
on public.fits (owner_id, created_at desc)
where deleted_at is null;

drop trigger if exists fits_set_updated_at on public.fits;

create trigger fits_set_updated_at
before update on public.fits
for each row
execute function public.set_updated_at();

alter table public.fits enable row level security;

-- Live fits are readable by anyone signed in; an owner also sees their own
-- hidden or deleted rows so the app can explain what happened to them.
drop policy if exists "Live fits are viewable by authenticated users"
on public.fits;

create policy "Live fits are viewable by authenticated users"
on public.fits
for select
to authenticated
using (
  (deleted_at is null and hidden_at is null)
  or owner_id = (select auth.uid())
);

drop policy if exists "Users can create their own fits"
on public.fits;

create policy "Users can create their own fits"
on public.fits
for insert
to authenticated
with check (owner_id = (select auth.uid()));

-- Soft delete only: the row survives so opponents' counters stay honest.
drop policy if exists "Users can retire their own fits"
on public.fits;

create policy "Users can retire their own fits"
on public.fits
for update
to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

-- Column-level grants are what actually stop an owner from writing their own
-- win counts: the update policy above permits the row, these permit only the
-- columns. wins/losses/report_count/hidden_at are reachable solely through the
-- security-definer functions in later migrations.
revoke insert, update, delete on public.fits from authenticated;

grant select on public.fits to authenticated;
grant insert (id, owner_id, image_path) on public.fits to authenticated;
grant update (deleted_at) on public.fits to authenticated;
