-- Outfit genres, and same-genre matchmaking.
--
-- Comparing a suit against a techwear fit asks the voter the wrong question:
-- they end up voting on which style they like rather than which outfit is
-- better put together. Every fit now declares a genre, and next_matchup()
-- draws both sides from the same one.
--
-- The genre is an enum rather than a lookup table because the app renders a
-- fixed picker for it: a new genre needs a Flutter release anyway, so there is
-- nothing to gain from making the set editable at runtime. Adding one later is
-- `alter type public.fit_genre add value 'grunge';` plus the matching Dart enum
-- entry in lib/features/fits/models/fit_genre.dart.

do $$
begin
  create type public.fit_genre as enum (
    'streetwear',
    'formal',
    'casual',
    'y2k',
    'techwear',
    'vintage'
  );
exception
  when duplicate_object then null;
end
$$;

alter table public.fits
add column if not exists genre public.fit_genre;

-- Fits that predate this column are the development seed rows, whose photos
-- are placeholders rather than real outfits. 'casual' keeps them matchable
-- against each other instead of stranding them outside every genre.
update public.fits set genre = 'casual' where genre is null;

-- No default: a fit's genre is a judgement about the photo, so an insert that
-- forgets it should fail rather than quietly land in 'casual'.
alter table public.fits alter column genre set not null;

-- Matchmaking now filters by genre before sampling, so the partial index
-- carries it.
create index if not exists fits_matchable_genre_idx
on public.fits (genre, id)
where deleted_at is null and hidden_at is null;

-- The old genre-less index is redundant: a leading-column scan of the one
-- above answers everything it did.
drop index if exists public.fits_matchable_idx;

-- Owners choose their fit's genre at upload time, so it joins the columns the
-- authenticated role may insert. It stays out of the update grant: a fit's
-- genre is fixed once it has battled, otherwise its win record would describe
-- comparisons it never had.
grant insert (id, owner_id, image_path, genre) on public.fits to authenticated;

-- Returns the two fits of the next matchup, both from one genre, or no rows
-- when the voter has exhausted every pair available to them.
--
-- The left-hand fit is sampled first and fixes the genre; the right-hand one
-- is then drawn from the same genre, still excluding the voter, the left fit's
-- owner, and pairs this voter has already settled. Sampling the genre through
-- a fit rather than picking a genre first keeps the odds proportional to how
-- many fits each genre holds, so a thin genre cannot stall the arena.
--
-- Dropped rather than replaced: the result now carries a genre column, and
-- `create or replace` cannot change a function's return type. The grant is
-- reissued at the bottom because dropping takes it with the function.
drop function if exists public.next_matchup();

create function public.next_matchup()
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
    order by random()
    limit 10
  loop
    select f.id
    into v_b
    from public.fits f
    where f.deleted_at is null
      and f.hidden_at is null
      -- Like against like: the voter judges the outfit, not the style.
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

revoke all on function public.next_matchup() from public, anon;
grant execute on function public.next_matchup() to authenticated;
