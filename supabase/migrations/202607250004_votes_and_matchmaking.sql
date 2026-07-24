-- Votes and matchmaking.
--
-- Pairs are ephemeral: nothing is stored until someone votes. The pair is
-- normalised so the smaller uuid is always fit_a_id, which lets a single
-- unique index enforce "one vote per user per pair" regardless of which side
-- each fit was shown on.
--
-- Votes are immutable and are never written directly by the client: the
-- authenticated role has no insert/update/delete privilege on the table, and
-- cast_vote() is the only way in. That keeps the vote row and the two counter
-- updates in one transaction that the client cannot take apart.

create table if not exists public.votes (
  id uuid primary key default gen_random_uuid(),
  voter_id uuid not null references public.profiles(id) on delete cascade,
  fit_a_id uuid not null references public.fits(id) on delete cascade,
  fit_b_id uuid not null references public.fits(id) on delete cascade,
  winner_id uuid not null references public.fits(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint votes_pair_normalised check (fit_a_id < fit_b_id),
  constraint votes_winner_in_pair check (winner_id in (fit_a_id, fit_b_id))
);

-- Enforces one vote per user per pair, and is the index next_matchup() probes
-- to skip pairs the voter has already settled.
create unique index if not exists votes_voter_pair_key
on public.votes (voter_id, fit_a_id, fit_b_id);

-- Feeds the win-streak calculation, which walks a user's fits' votes backwards.
create index if not exists votes_created_at_idx
on public.votes (created_at desc);

create index if not exists votes_fit_a_idx on public.votes (fit_a_id);
create index if not exists votes_fit_b_idx on public.votes (fit_b_id);

alter table public.votes enable row level security;

drop policy if exists "Users can view their own votes"
on public.votes;

create policy "Users can view their own votes"
on public.votes
for select
to authenticated
using (voter_id = (select auth.uid()));

revoke insert, update, delete on public.votes from authenticated;
grant select on public.votes to authenticated;

-- Returns the two fits of the next matchup, or no rows when the voter has
-- exhausted the pool. Random sampling is `order by random()`, which is a full
-- scan of the matchable set; fine at current scale, and the partial index
-- keeps that set as small as possible. Revisit if the pool gets large.
create or replace function public.next_matchup()
returns table (
  fit_id uuid,
  owner_id uuid,
  username text,
  display_name text,
  image_path text,
  wins integer,
  losses integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_voter uuid := auth.uid();
  v_a uuid;
  v_b uuid;
begin
  if v_voter is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  -- Try a handful of candidate left-hand fits: an unlucky first pick may be
  -- one this voter has already faced against everything else.
  for v_a in
    select f.id
    from public.fits f
    where f.deleted_at is null
      and f.hidden_at is null
      and f.owner_id <> v_voter
    order by random()
    limit 10
  loop
    select f.id
    into v_b
    from public.fits f
    where f.deleted_at is null
      and f.hidden_at is null
      and f.owner_id <> v_voter
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
    f.wins,
    f.losses
  from public.fits f
  join public.profiles p on p.id = f.owner_id
  where f.id in (v_a, v_b)
  order by case when f.id = v_a then 0 else 1 end;
end;
$$;

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

  update public.fits set wins = wins + 1 where id = p_winner_id;
  update public.fits set losses = losses + 1 where id = p_loser_id;
end;
$$;

revoke all on function public.next_matchup() from public, anon;
revoke all on function public.cast_vote(uuid, uuid) from public, anon;
grant execute on function public.next_matchup() to authenticated;
grant execute on function public.cast_vote(uuid, uuid) to authenticated;
