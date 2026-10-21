create table if not exists public.player_progress (
  player_id uuid primary key references auth.users(id) on delete cascade,
  unlocked_level integer not null default 1 check (unlocked_level between 1 and 100),
  completed_levels integer[] not null default '{}',
  xp integer not null default 0,
  coins integer not null default 0,
  inventory jsonb not null default '{"Hint Token":0,"Skip Token":0,"Combo Shield":0,"XP Surge":0}'::jsonb,
  profile_name text not null default 'SQL Explorer',
  equipped_badge text not null default 'None',
  name_card text not null default 'Classic Blue',
  owned_badges text[] not null default '{}',
  owned_name_cards text[] not null default '{}',
  xp_surge_armed boolean not null default false,
  hints_by_level jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- Safe upgrades for an existing install of the earlier prototype schema.
alter table public.player_progress drop constraint if exists player_progress_unlocked_level_check;
alter table public.player_progress add constraint player_progress_unlocked_level_check check (unlocked_level between 1 and 100);
alter table public.player_progress add column if not exists xp integer not null default 0;
alter table public.player_progress add column if not exists coins integer not null default 0;
alter table public.player_progress add column if not exists inventory jsonb not null default '{"Hint Token":0,"Skip Token":0,"Combo Shield":0,"XP Surge":0}'::jsonb;
alter table public.player_progress add column if not exists profile_name text not null default 'SQL Explorer';
alter table public.player_progress add column if not exists equipped_badge text not null default 'None';
alter table public.player_progress add column if not exists name_card text not null default 'Classic Blue';
alter table public.player_progress add column if not exists owned_badges text[] not null default '{}';
alter table public.player_progress add column if not exists owned_name_cards text[] not null default '{}';
alter table public.player_progress add column if not exists xp_surge_armed boolean not null default false;
alter table public.player_progress add column if not exists hints_by_level jsonb not null default '{}'::jsonb;

alter table public.player_progress enable row level security;

drop policy if exists "prototype progress access" on public.player_progress;
drop policy if exists "players manage their own progress" on public.player_progress;
create policy "players manage their own progress"
  on public.player_progress for all
  to authenticated
  using (auth.uid() = player_id)
  with check (auth.uid() = player_id);
