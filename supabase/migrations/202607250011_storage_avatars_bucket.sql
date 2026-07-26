-- Storage for profile photos.
--
-- Public bucket, for the same reason as `fits`: profiles are readable by every
-- authenticated user, and a matchup should not need a signing round trip
-- before it can show whose fit it is. Write access is scoped by folder, where
-- the first path segment is the owner's uuid:
--
--   avatars/<owner_id>/<unique-file-name>
--
-- `profiles.avatar_url` holds a full URL rather than a path: the column
-- already carries Google's avatar URL for accounts that never uploaded one,
-- and both kinds render through the same `Image.network`.
--
-- Smaller cap than `fits`: an avatar is cropped square and downscaled on
-- device before it ever reaches the bucket.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880, -- 5 MB
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Avatar images are publicly readable"
on storage.objects;

create policy "Avatar images are publicly readable"
on storage.objects
for select
to public
using (bucket_id = 'avatars');

drop policy if exists "Users can upload their own avatar"
on storage.objects;

create policy "Users can upload their own avatar"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users can replace their own avatar"
on storage.objects;

create policy "Users can replace their own avatar"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

-- Replacing or clearing a photo purges the file it leaves behind, so the
-- bucket does not accumulate every avatar a user ever had.
drop policy if exists "Users can delete their own avatar"
on storage.objects;

create policy "Users can delete their own avatar"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
