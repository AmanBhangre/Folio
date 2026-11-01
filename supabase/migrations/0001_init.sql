-- Folio cloud sync. Only saves leave the phone; game files never do.
--
-- A game is identified by its Twine IFID when it has one (stable across
-- zips, devices and renames), else by a hash of its title the app computes.

create table public.devices (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  name        text not null,
  platform    text not null check (platform in ('ios', 'android')),
  last_seen   timestamptz not null default now(),
  created_at  timestamptz not null default now()
);

create table public.games (
  user_id     uuid not null references auth.users (id) on delete cascade,
  game_key    text not null,               -- IFID, or 'title:<sha1>' without one
  title       text not null,
  version     text not null default '',
  updated_at  timestamptz not null default now(),
  primary key (user_id, game_key)
);

-- One row per game: the latest full save state. History lives on the device
-- (10 local backups); the cloud copy is for moving between devices.
create table public.saves (
  user_id       uuid not null references auth.users (id) on delete cascade,
  game_key      text not null,
  storage_path  text not null,             -- object in the 'saves' bucket
  size_bytes    integer not null,
  sha256        text not null,             -- skip uploads when nothing changed
  device_id     uuid references public.devices (id) on delete set null,
  updated_at    timestamptz not null default now(),
  primary key (user_id, game_key),
  foreign key (user_id, game_key) references public.games (user_id, game_key) on delete cascade
);

-- Set by the RevenueCat webhook (Edge Function), never by the client.
create table public.entitlements (
  user_id     uuid primary key references auth.users (id) on delete cascade,
  sync_active boolean not null default false,
  expires_at  timestamptz,
  updated_at  timestamptz not null default now()
);

alter table public.devices      enable row level security;
alter table public.games        enable row level security;
alter table public.saves        enable row level security;
alter table public.entitlements enable row level security;

create policy "own devices" on public.devices
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own games" on public.games
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Writing saves needs an active subscription; reading your own never does,
-- so a lapsed subscriber can still pull their saves down.
create policy "read own saves" on public.saves
  for select using (auth.uid() = user_id);
create policy "write own saves when subscribed" on public.saves
  for insert with check (
    auth.uid() = user_id
    and exists (select 1 from public.entitlements e where e.user_id = auth.uid() and e.sync_active)
  );
create policy "update own saves when subscribed" on public.saves
  for update using (auth.uid() = user_id) with check (
    auth.uid() = user_id
    and exists (select 1 from public.entitlements e where e.user_id = auth.uid() and e.sync_active)
  );
create policy "delete own saves" on public.saves
  for delete using (auth.uid() = user_id);

create policy "read own entitlement" on public.entitlements
  for select using (auth.uid() = user_id);

-- Private bucket; each user's objects live under '<user_id>/'.
insert into storage.buckets (id, name, public) values ('saves', 'saves', false)
  on conflict (id) do nothing;

create policy "own save objects read" on storage.objects
  for select using (bucket_id = 'saves' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own save objects write" on storage.objects
  for insert with check (bucket_id = 'saves' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own save objects update" on storage.objects
  for update using (bucket_id = 'saves' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own save objects delete" on storage.objects
  for delete using (bucket_id = 'saves' and (storage.foldername(name))[1] = auth.uid()::text);
