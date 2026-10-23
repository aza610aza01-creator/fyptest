-- =============================================================================
-- AI GYM CLOUD - PRIVATE SUPABASE STORAGE BUCKETS AND RLS POLICIES
-- =============================================================================
-- Creates private buckets for progress photos and optional consent-gated
-- camera detection images. Public listing is strictly disabled.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('progress-photos', 'progress-photos', false, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('camera-detections', 'camera-detections', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- Users may only access files inside their own folder: <auth.uid()>/<filename>
drop policy if exists "private_progress_photos_select" on storage.objects;
create policy "private_progress_photos_select" on storage.objects
  for select to authenticated
  using (
    bucket_id in ('progress-photos', 'camera-detections')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "private_progress_photos_insert" on storage.objects;
create policy "private_progress_photos_insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('progress-photos', 'camera-detections')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "private_progress_photos_update" on storage.objects;
create policy "private_progress_photos_update" on storage.objects
  for update to authenticated
  using (
    bucket_id in ('progress-photos', 'camera-detections')
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id in ('progress-photos', 'camera-detections')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "private_progress_photos_delete" on storage.objects;
create policy "private_progress_photos_delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id in ('progress-photos', 'camera-detections')
    and (storage.foldername(name))[1] = auth.uid()::text
  );
