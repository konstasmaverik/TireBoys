-- Group activity feed for notifications: run after schema.sql + avatars.sql.
-- Returns fellow group members' drives uploaded after the given watermark.
-- security definer because drives are owner-only under RLS; membership is
-- still enforced by the auth.uid() join below.

create or replace function public.recent_group_activity(p_since timestamptz)
returns table (
  group_name text,
  username text,
  started_at timestamptz,
  distance_meters double precision,
  top_speed_mps double precision,
  uploaded_at timestamptz
)
language sql security definer set search_path = public stable as $$
  select g.name, p.username, d.started_at, d.distance_meters, d.top_speed_mps, d.created_at
  from drives d
  join profiles p on p.id = d.user_id
  join group_members gm on gm.user_id = d.user_id
  join groups g on g.id = gm.group_id
  where gm.group_id in (select group_id from group_members where user_id = auth.uid())
    and d.user_id <> auth.uid()
    and d.created_at > p_since
  order by d.created_at desc
  limit 20
$$;
