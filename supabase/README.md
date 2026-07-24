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

Seeded accounts all use the `@versed-seed.invalid` email domain — `.invalid` is
reserved by RFC 2606 and can never belong to a real person, which is what makes
`--clean` safe to run. Deleting the account cascades to its profile, fits and
votes; the script clears its storage folder first, since that is not covered by
the cascade.
