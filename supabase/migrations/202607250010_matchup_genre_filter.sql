-- Letting the voter choose which genre they are judging.
--
-- next_matchup() already draws both sides from one genre, but which genre was
-- luck of the draw. The arena now carries a category strip, so the client can
-- ask for a specific one and stay in it.
--
-- The parameter is text rather than public.fit_genre: PostgREST sends JSON, and
-- a text argument keeps the RPC callable with a plain string instead of a
-- qualified enum cast on the wire. It is cast once below, so an unrecognised
-- value still fails loudly (22P02) rather than silently matching nothing.
--
-- Dropped rather than replaced: adding a parameter with a default would leave
-- the old zero-argument function in place as a second overload, and every call
-- would then be ambiguous.
drop function if exists public.next_matchup();

create function public.next_matchup(p_genre text default null)
returns table (
  fit_id uuid,
  owner_id uuid,
  username text,
  display_name text,
  image_path text,
  genre text,
  wins integer,
  losses integer
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
    f.losses
  from public.fits f
  join public.profiles p on p.id = f.owner_id
  where f.id in (v_a, v_b)
  order by case when f.id = v_a then 0 else 1 end;
end;
$$;

revoke all on function public.next_matchup(text) from public, anon;
grant execute on function public.next_matchup(text) to authenticated;
