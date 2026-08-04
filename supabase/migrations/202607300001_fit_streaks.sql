-- Per-fit win streaks.
--
-- The streak used to be a property of the person: profile_stats() walked every
-- vote their fits had taken part in and counted back to the first loss. That
-- answered "how is this user doing", not "is this outfit on a run", and it cost
-- a full scan of votes on every profile load.
--
-- Streaks now live on the fit, maintained by cast_vote() the same way wins and
-- losses already are. current_streak is the run in progress; best_streak is the
-- high-water mark, which is what the profile shows.

alter table public.fits
  add column if not exists current_streak integer not null default 0
    check (current_streak >= 0),
  add column if not exists best_streak integer not null default 0
    check (best_streak >= 0);

-- Backfill from the vote history. Every vote a fit took part in is an outcome
-- for it, whichever side of the pair it landed on.
with outcomes as (
  select
    f.id as fit_id,
    v.created_at,
    (v.winner_id = f.id) as won
  from public.fits f
  join public.votes v on f.id in (v.fit_a_id, v.fit_b_id)
),
-- Newest first: a vote belongs to the current run while no loss has been seen
-- at or before it.
current_run as (
  select
    fit_id,
    count(*) filter (where losses_since = 0 and won) as streak
  from (
    select
      fit_id,
      won,
      sum(case when won then 0 else 1 end) over (
        partition by fit_id
        order by created_at desc
        rows between unbounded preceding and current row
      ) as losses_since
    from outcomes
  ) scanned
  group by fit_id
),
-- Oldest first: each loss opens a new group, so the wins inside a group are one
-- unbroken run and the longest of them is the record.
best_run as (
  select fit_id, coalesce(max(run_length), 0) as streak
  from (
    select fit_id, run, count(*) filter (where won) as run_length
    from (
      select
        fit_id,
        won,
        sum(case when won then 0 else 1 end) over (
          partition by fit_id
          order by created_at
          rows between unbounded preceding and current row
        ) as run
      from outcomes
    ) grouped
    group by fit_id, run
  ) runs
  group by fit_id
)
-- Both runs are grouped from the same outcomes, so every fit with a vote
-- history appears in each. Fits with no votes keep the column defaults.
update public.fits f
set current_streak = c.streak, best_streak = b.streak
from current_run c
join best_run b on b.fit_id = c.fit_id
where f.id = c.fit_id;

-- Records a vote and moves both counters atomically. Raises rather than
-- silently no-oping so the client can tell a duplicate from a success.
create or replace function public.cast_vote(
  p_winner_id uuid,
  p_loser_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_voter uuid := auth.uid();
  v_winner_owner uuid;
  v_loser_owner uuid;
  v_inserted integer;
begin
  if v_voter is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  if p_winner_id = p_loser_id then
    raise exception 'a fit cannot battle itself' using errcode = '22023';
  end if;

  -- Lock both rows in a stable order so concurrent votes on the same pair
  -- cannot deadlock against each other.
  select f.owner_id into v_winner_owner
  from public.fits f
  where f.id = p_winner_id
    and f.deleted_at is null
    and f.hidden_at is null
  for update;

  select f.owner_id into v_loser_owner
  from public.fits f
  where f.id = p_loser_id
    and f.deleted_at is null
    and f.hidden_at is null
  for update;

  if v_winner_owner is null or v_loser_owner is null then
    raise exception 'fit is unavailable' using errcode = '22023';
  end if;

  if v_voter in (v_winner_owner, v_loser_owner) then
    raise exception 'cannot vote on your own fit' using errcode = '42501';
  end if;

  insert into public.votes (voter_id, fit_a_id, fit_b_id, winner_id)
  values (
    v_voter,
    least(p_winner_id, p_loser_id),
    greatest(p_winner_id, p_loser_id),
    p_winner_id
  )
  on conflict (voter_id, fit_a_id, fit_b_id) do nothing;

  get diagnostics v_inserted = row_count;

  if v_inserted = 0 then
    raise exception 'already voted on this matchup' using errcode = '23505';
  end if;

  -- Both rows are already locked above, so the streak can be advanced from its
  -- own value without re-reading it.
  update public.fits
  set
    wins = wins + 1,
    current_streak = current_streak + 1,
    best_streak = greatest(best_streak, current_streak + 1)
  where id = p_winner_id;

  update public.fits
  set losses = losses + 1, current_streak = 0
  where id = p_loser_id;
end;
$$;

-- next_matchup() and profile_stats() both change their result columns, and
-- Postgres will not let create-or-replace alter a function's return type.
drop function if exists public.next_matchup(text);

create function public.next_matchup(p_genre text default null)
returns table (
  fit_id uuid,
  owner_id uuid,
  username text,
  display_name text,
  image_path text,
  genre text,
  wins integer,
  losses integer,
  current_streak integer,
  best_streak integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_voter uuid := auth.uid();
  -- Null means "any genre", which is the arena's default and its behaviour
  -- before this migration.
  v_filter public.fit_genre := nullif(p_genre, '')::public.fit_genre;
  v_a uuid;
  v_a_owner uuid;
  v_a_genre public.fit_genre;
  v_b uuid;
begin
  if v_voter is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  -- Try a handful of candidate left-hand fits: an unlucky first pick may be
  -- the only fit in its genre, or one this voter has already faced against
  -- everything else in it.
  for v_a, v_a_owner, v_a_genre in
    select f.id, f.owner_id, f.genre
    from public.fits f
    where f.deleted_at is null
      and f.hidden_at is null
      and f.owner_id <> v_voter
      and (v_filter is null or f.genre = v_filter)
    order by random()
    limit 10
  loop
    select f.id
    into v_b
    from public.fits f
    where f.deleted_at is null
      and f.hidden_at is null
      -- Like against like: the voter judges the outfit, not the style. The
      -- filter is already implied here, since the left fit satisfied it.
      and f.genre = v_a_genre
      and f.owner_id <> v_voter
      -- A battle is between two people, so the opponent must be someone else.
      and f.owner_id <> v_a_owner
      and f.id <> v_a
      and not exists (
        select 1
        from public.votes v
        where v.voter_id = v_voter
          and v.fit_a_id = least(v_a, f.id)
          and v.fit_b_id = greatest(v_a, f.id)
      )
    order by random()
    limit 1;

    exit when v_b is not null;
  end loop;

  if v_b is null then
    return;
  end if;

  return query
  select
    f.id,
    f.owner_id,
    p.username,
    p.display_name,
    f.image_path,
    f.genre::text,
    f.wins,
    f.losses,
    f.current_streak,
    f.best_streak
  from public.fits f
  join public.profiles p on p.id = f.owner_id
  where f.id in (v_a, v_b)
  order by case when f.id = v_a then 0 else 1 end;
end;
$$;

revoke all on function public.next_matchup(text) from public, anon;
grant execute on function public.next_matchup(text) to authenticated;

-- Profile stats: the numbers behind ProfileStats in the Flutter app.
--
-- All three come from the owner's live fits, matching what the profile grid
-- shows. best_streak is the longest run any one of those fits has put
-- together, so it survives a loss — unlike the per-user current streak this
-- replaces, which the next vote against any fit could wipe out.
drop function if exists public.profile_stats(uuid);

create function public.profile_stats(p_profile_id uuid)
returns table (
  wins integer,
  losses integer,
  best_streak integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce(sum(f.wins), 0)::integer,
    coalesce(sum(f.losses), 0)::integer,
    coalesce(max(f.best_streak), 0)::integer
  from public.fits f
  where f.owner_id = p_profile_id
    and f.deleted_at is null;
$$;

revoke all on function public.profile_stats(uuid) from public, anon;
grant execute on function public.profile_stats(uuid) to authenticated;
