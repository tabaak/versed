-- Never pit one person against themselves.
--
-- The original next_matchup() excluded fits owned by the voter, but nothing
-- stopped both sides of a pair belonging to the same third party. With three
-- fits per owner that was roughly 8% of matchups: the winner and the loser
-- were the same person, so their win rate drifted toward 50% for no reason and
-- profile_stats() had to discard the vote when counting streaks.
--
-- Picking the right-hand fit now also excludes the left-hand fit's owner.

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
  v_a_owner uuid;
  v_b uuid;
begin
  if v_voter is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  -- Try a handful of candidate left-hand fits: an unlucky first pick may be
  -- one this voter has already faced against everything else.
  for v_a, v_a_owner in
    select f.id, f.owner_id
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
      -- A battle is between two people, so the opponent must be someone else.
      and f.owner_id <> v_a_owner
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
