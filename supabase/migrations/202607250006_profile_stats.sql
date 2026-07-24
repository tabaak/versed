-- Profile stats: the numbers behind ProfileStats in the Flutter app.
--
-- wins/losses are summed from the owner's live fits, matching what the profile
-- grid shows. The streak is consecutive wins across all of those fits, ordered
-- by vote time and reset by the first loss.

create or replace function public.profile_stats(p_profile_id uuid)
returns table (
  wins integer,
  losses integer,
  current_streak integer
)
language sql
stable
security definer
set search_path = public
as $$
  with owned as (
    select id
    from public.fits
    where owner_id = p_profile_id
      and deleted_at is null
  ),
  totals as (
    select
      coalesce(sum(f.wins), 0)::integer as wins,
      coalesce(sum(f.losses), 0)::integer as losses
    from public.fits f
    join owned o on o.id = f.id
  ),
  -- Every vote one of those fits took part in. A pair where both fits belong
  -- to this user is neither a win nor a loss for them, so it is dropped.
  outcomes as (
    select
      v.created_at,
      (fw.owner_id = p_profile_id) as won
    from public.votes v
    join public.fits fw on fw.id = v.winner_id
    where (v.fit_a_id in (select id from owned) or v.fit_b_id in (select id from owned))
      and not (
        v.fit_a_id in (select id from owned)
        and v.fit_b_id in (select id from owned)
      )
  ),
  -- Walking backwards from the most recent vote, a row is part of the current
  -- streak while no loss has been seen at or before it.
  scanned as (
    select
      won,
      sum(case when won then 0 else 1 end) over (
        order by created_at desc
        rows between unbounded preceding and current row
      ) as losses_so_far
    from outcomes
  )
  select
    t.wins,
    t.losses,
    (select count(*) from scanned where losses_so_far = 0 and won)::integer
  from totals t;
$$;

revoke all on function public.profile_stats(uuid) from public, anon;
grant execute on function public.profile_stats(uuid) to authenticated;
