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
