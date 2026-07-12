-- Avatar support: run after schema.sql (SQL Editor → Run).

alter table public.profiles add column avatar_url text;

-- Public bucket: avatar images are non-sensitive and public URLs keep
-- display simple. Uploads are locked to each user's own file name.
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true);

create policy "avatar images are publicly readable"
  on storage.objects for select
  using (bucket_id = 'avatars');

create policy "users upload their own avatar"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and name = auth.uid()::text || '.jpg');

create policy "users replace their own avatar"
  on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and name = auth.uid()::text || '.jpg');

-- Leaderboard now returns avatars too.
drop function public.group_leaderboard(uuid, timestamptz);

create or replace function public.group_leaderboard(p_group_id uuid, p_since timestamptz)
returns table (
  user_id uuid,
  username text,
  avatar_url text,
  total_distance_meters double precision,
  total_duration_seconds double precision,
  top_speed_mps double precision,
  drive_count bigint
)
language sql security definer set search_path = public stable as $$
  select
    p.id,
    p.username,
    p.avatar_url,
    coalesce(sum(d.distance_meters), 0),
    coalesce(sum(d.duration_seconds), 0),
    coalesce(max(d.top_speed_mps), 0),
    count(d.id)
  from group_members gm
  join profiles p on p.id = gm.user_id
  left join drives d
    on d.user_id = gm.user_id
    and (p_since is null or d.started_at >= p_since)
  where gm.group_id = p_group_id
    and public.is_group_member(p_group_id, auth.uid())
  group by p.id, p.username, p.avatar_url
$$;
