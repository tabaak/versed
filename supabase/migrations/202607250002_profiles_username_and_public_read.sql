-- Usernames and public profile visibility.
--
-- Google OAuth gives no handle, so username stays nullable: the app routes a
-- signed-in user with a null username into a pick-a-handle step. The format
-- check forbids uppercase, so a plain unique index is enough to make handles
-- case-insensitively unique.

alter table public.profiles
  add column if not exists username text;

do $$
begin
  alter table public.profiles
    add constraint profiles_username_format
    check (username ~ '^[a-z0-9_]{3,20}$');
exception
  when duplicate_object then null;
end;
$$;

create unique index if not exists profiles_username_key
on public.profiles (username);

-- Shared updated_at maintenance, used by every table from here on.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;

create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

-- Profiles become publicly readable: a voter can see whose fit won.
drop policy if exists "Users can view their own profile"
on public.profiles;

drop policy if exists "Profiles are viewable by authenticated users"
on public.profiles;

create policy "Profiles are viewable by authenticated users"
on public.profiles
for select
to authenticated
using (true);

-- Writes stay owner-only. The insert policy from the baseline still applies;
-- it is restated here so this file is self-contained on a fresh database.
drop policy if exists "Users can create their own profile"
on public.profiles;

create policy "Users can create their own profile"
on public.profiles
for insert
to authenticated
with check ((select auth.uid()) = id);

drop policy if exists "Users can update their own profile"
on public.profiles;

create policy "Users can update their own profile"
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);
