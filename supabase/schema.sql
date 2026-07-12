-- DriveStats schema. Paste into Supabase Dashboard → SQL Editor → Run.
-- Everything is locked down by row-level security; the anon key alone can
-- read nothing.

-- ---------------------------------------------------------------- profiles

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique
    check (username ~ '^[a-z0-9_]{3,20}$'),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Any signed-in user can look up profiles (needed for username search);
-- only the owner can create/update their own row.
create policy "profiles are readable by authenticated users"
  on public.profiles for select to authenticated using (true);
create policy "users insert their own profile"
  on public.profiles for insert to authenticated
  with check (id = auth.uid());
create policy "users update their own profile"
  on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Create the profile automatically on sign-up, taking the username from the
-- sign-up metadata so profile creation can't be skipped by a buggy client.
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username)
  values (new.id, lower(new.raw_user_meta_data ->> 'username'));
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ------------------------------------------------------------------ drives
-- Synced aggregates only — no GPS route points ever leave the phone.

create table public.drives (
  id uuid primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  distance_meters double precision not null check (distance_meters >= 0),
  duration_seconds double precision not null check (duration_seconds >= 0),
  top_speed_mps double precision not null check (top_speed_mps >= 0),
  created_at timestamptz not null default now()
);

create index drives_user_started on public.drives (user_id, started_at desc);

alter table public.drives enable row level security;

-- Owner-only: leaderboards read these through the security-definer function
-- below, so nobody can browse anyone else's individual drives.
create policy "users manage their own drives"
  on public.drives for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ------------------------------------------------------------- friendships

create table public.friendships (
  requester_id uuid not null references public.profiles (id) on delete cascade,
  addressee_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  primary key (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

alter table public.friendships enable row level security;

create policy "parties read their friendships"
  on public.friendships for select to authenticated
  using (requester_id = auth.uid() or addressee_id = auth.uid());
create policy "users send friend requests"
  on public.friendships for insert to authenticated
  with check (requester_id = auth.uid() and status = 'pending');
create policy "addressee accepts the request"
  on public.friendships for update to authenticated
  using (addressee_id = auth.uid()) with check (status = 'accepted');
create policy "either party removes the friendship"
  on public.friendships for delete to authenticated
  using (requester_id = auth.uid() or addressee_id = auth.uid());

-- ------------------------------------------------------------------ groups

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 40),
  invite_code text not null unique default encode(gen_random_bytes(4), 'hex'),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.group_members (
  group_id uuid not null references public.groups (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

alter table public.groups enable row level security;
alter table public.group_members enable row level security;

-- Avoids infinite recursion in group_members policies.
create or replace function public.is_group_member(p_group_id uuid, p_user_id uuid)
returns boolean
language sql security definer set search_path = public stable as $$
  select exists (
    select 1 from group_members
    where group_id = p_group_id and user_id = p_user_id
  )
$$;

create policy "members read their groups"
  on public.groups for select to authenticated
  using (public.is_group_member(id, auth.uid()));
create policy "owner deletes the group"
  on public.groups for delete to authenticated
  using (owner_id = auth.uid());

create policy "members see fellow members"
  on public.group_members for select to authenticated
  using (public.is_group_member(group_id, auth.uid()));
create policy "members leave groups"
  on public.group_members for delete to authenticated
  using (user_id = auth.uid());

-- Creating and joining go through functions so membership rows and invite
-- codes stay consistent (clients never insert into these tables directly).

create or replace function public.create_group(p_name text)
returns public.groups
language plpgsql security definer set search_path = public as $$
declare g public.groups;
begin
  insert into groups (name, owner_id) values (p_name, auth.uid()) returning * into g;
  insert into group_members (group_id, user_id) values (g.id, auth.uid());
  return g;
end $$;

create or replace function public.join_group(p_invite_code text)
returns public.groups
language plpgsql security definer set search_path = public as $$
declare g public.groups;
begin
  select * into g from groups where invite_code = lower(p_invite_code);
  if g.id is null then
    raise exception 'invalid invite code';
  end if;
  insert into group_members (group_id, user_id)
  values (g.id, auth.uid())
  on conflict do nothing;
  return g;
end $$;

-- ------------------------------------------------------------- leaderboard

create or replace function public.group_leaderboard(p_group_id uuid, p_since timestamptz)
returns table (
  user_id uuid,
  username text,
  total_distance_meters double precision,
  total_duration_seconds double precision,
  top_speed_mps double precision,
  drive_count bigint
)
language sql security definer set search_path = public stable as $$
  select
    p.id,
    p.username,
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
  group by p.id, p.username
$$;
