-- Case-insensitive folder policy for profile pictures bucket
-- Run this after 02_storage.sql to replace the storage policies.

-- Drop existing policies if present
drop policy if exists "Public read access for profile pictures" on storage.objects;
drop policy if exists "Users can upload to their folder" on storage.objects;
drop policy if exists "Users can manage their files" on storage.objects;
drop policy if exists "Users can delete their files" on storage.objects;

-- Public read remains the same
create policy "Public read access for profile pictures"
on storage.objects for select
using ( bucket_id = 'profile-pictures' );

-- Case-insensitive match on the first folder (user id)
-- Insert: allow only into a folder matching the caller's uid
create policy "Users can upload to their folder"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'profile-pictures'
  and lower((storage.foldername(name))[1]) = lower(auth.uid()::text)
);

-- Update: only within own folder
create policy "Users can manage their files"
on storage.objects for update to authenticated using (
  bucket_id = 'profile-pictures'
  and lower((storage.foldername(name))[1]) = lower(auth.uid()::text)
) with check (
  bucket_id = 'profile-pictures'
  and lower((storage.foldername(name))[1]) = lower(auth.uid()::text)
);

-- Delete: only within own folder
create policy "Users can delete their files"
on storage.objects for delete to authenticated using (
  bucket_id = 'profile-pictures'
  and lower((storage.foldername(name))[1]) = lower(auth.uid()::text)
);

