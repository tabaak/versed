-- Storage for outfit photos.
--
-- Public bucket: image URLs are stable and CDN-cacheable, and the arena needs
-- no signing round trip before it can render a matchup. Write access is scoped
-- by folder, where the first path segment is the owner's uuid:
--
--   fits/<owner_id>/<fit_id>
--
-- Nothing secret belongs in this bucket; a fit photo is public the moment it
-- enters the arena.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'fits',
  'fits',
  true,
  10485760, -- 10 MB
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Fit images are publicly readable"
on storage.objects;

create policy "Fit images are publicly readable"
on storage.objects
for select
to public
using (bucket_id = 'fits');

drop policy if exists "Users can upload their own fit images"
on storage.objects;

create policy "Users can upload their own fit images"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'fits'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users can replace their own fit images"
on storage.objects;

create policy "Users can replace their own fit images"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'fits'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'fits'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

-- Soft-deleting a fit keeps its row and its votes, but the owner may still
-- purge the image itself.
drop policy if exists "Users can delete their own fit images"
on storage.objects;

create policy "Users can delete their own fit images"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'fits'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
