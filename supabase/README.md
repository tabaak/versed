# Supabase schema

This directory stores the SQL definition of the hosted Supabase database so
database changes are visible and reviewable in GitHub.

The project currently uses a dashboard-first workflow. Supabase SQL files are
run manually in the hosted project's SQL Editor; the Supabase CLI and a local
Supabase stack are not required.

## Applying a change

1. Create a timestamped SQL file in `migrations/`.
2. Review and run the SQL in the Supabase SQL Editor.
3. Commit the SQL file with the related application changes.

Example:

```text
supabase/migrations/202607260001_add_username_to_profiles.sql
```

Never commit database passwords, connection strings, service-role keys, Google
OAuth secrets, access tokens, or other privileged credentials. Client
publishable keys are configured in Flutter through `--dart-define` and are not
stored in these SQL files.

## Existing hosted database

`202607250001_profiles_baseline.sql` records the initial schema that was already
applied through the Supabase dashboard. Its statements are idempotent so the
baseline can also be run against the existing hosted project safely.

## Filling the arena for development

`tool/seed_arena.dart` creates throwaway users, gives them fits, and casts
votes between them. Seeding your own account would not work: `cast_vote()`
refuses votes on your own fits, so an arena stocked only by you is empty.

It needs the service-role key to bypass RLS. Keep it in the environment, never
in a file:

```bash
export SUPABASE_URL='https://<project>.supabase.co'
export SUPABASE_SERVICE_ROLE_KEY='<service-role key>'

dart run tool/seed_arena.dart                 # 8 users x 3 fits, 40 votes
dart run tool/seed_arena.dart --download 30   # placeholder photos, not outfits
dart run tool/seed_arena.dart --images ~/fits # your own directory of photos
dart run tool/seed_arena.dart --clean --yes   # remove every seeded account
```

By default the photos come from `assets/auth/`, the six outfits already bundled
with the app. Fits are handed out round-robin, so with more fits than photos the
same outfit appears under several handles.

Seeded accounts take their handles and names from the shared pool in
`tool/seed_identities.dart`, so a filled arena does not read as a wall of bots.
Their email domain is what identifies them: `@versed-seed.invalid` — `.invalid`
is reserved by RFC 2606 and can never belong to a real person, which is what makes
`--clean` safe to run. Deleting the account cascades to its profile, fits and
votes; the script clears its storage folder first, since that is not covered by
the cascade.

## Entering real outfits by hand

`tool/tag_fits.dart` is the tool for stocking the arena with actual outfits
under genres you have judged yourself. `next_matchup()` only pairs fits from the
same genre, so the genre is a real decision about the photo rather than metadata
— and judging it means looking at it. The tool therefore serves a page on
localhost that shows one photo at a time with a button per genre:

```bash
export SUPABASE_URL='https://<project>.supabase.co'
export SUPABASE_SERVICE_ROLE_KEY='<service-role key>'

dart run tool/tag_fits.dart --images ~/outfits             # tag and enter
dart run tool/tag_fits.dart --images ~/outfits --owners 8  # wider owner pool
dart run tool/tag_fits.dart --images ~/outfits --all       # revisit tagged ones
```

Press `1`–`6` to pick a genre, `S` to skip, `←` to go back. Picking a genre
uploads that photo and creates its fit immediately, so quitting halfway keeps
everything already tagged.

Every fit is assigned to one of a pool of throwaway test accounts (`--owners N`,
six by default), in a per-session random order, and the page and terminal name
whoever it went to: `outfit4.jpg entered as Vintage for @novareyes`. Existing
seed accounts are reused, so `seed_arena --clean --yes` removes these as well.

Each genre rotates through the owner pool *independently*, because a genre
holding one person's fits can never produce a matchup: matchmaking pairs within
a genre and a battle is always between two people. The tool prints the
fits-and-owners tally per genre when it stops, and names any genre still stuck
on a single owner.

Handles come from the pool in `tool/seed_identities.dart` — `@novareyes`,
`@wren_c`, `@mika_tnk` — because the arena shows a fit's owner and
`arena_seed_48213_0` tells anyone using the app that they are judging filler.
Accounts are still identified purely by their `@versed-seed.invalid` address,
which nothing in the app exposes, so `--clean` stays exact. Any account left
over from before the pool existed is renamed to a plausible handle the first
time either tool picks it up.

Photos already entered are recorded in `.versed-tagged.json` next to them and
skipped on the next run, so a large directory can be worked through over several
sittings. Re-tagging a photo from the page moves the existing fit to the new
genre instead of uploading a second copy.
