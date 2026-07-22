-- =====================================================================
-- ICU Case Simulator — Supabase schema (Phase 1: accounts + saved progress)
-- Run this once in the Supabase dashboard → SQL Editor → New query → Run.
-- Safe to re-run: everything is guarded with "if not exists" / "or replace".
-- =====================================================================

-- ---------------------------------------------------------------------
-- profiles: one row per user, holds display name + role.
-- The row is created automatically on sign-up by the trigger below.
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id           uuid primary key references auth.users on delete cascade,
  display_name text,
  role         text not null default 'student' check (role in ('student','instructor')),
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- attempts: one row per completed scenario attempt (any module).
-- ---------------------------------------------------------------------
create table if not exists public.attempts (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users on delete cascade,
  module          text not null,          -- 'icu' | 'ventilator' | 'abg' | 'procedure'
  scenario_id     text not null,          -- case/preset/procedure id
  scenario_label  text,                   -- human-readable title
  outcome         text,                   -- e.g. 'stabilised','death','clean','arrest','2/3'
  score           numeric,                -- normalised 0..1 where applicable, else null
  critical_errors int  default 0,
  cautions        int  default 0,
  duration_min    int,
  detail          jsonb,                  -- flexible extras (log, complications, etc.)
  created_at      timestamptz not null default now()
);

create index if not exists attempts_user_id_idx  on public.attempts (user_id, created_at desc);
create index if not exists attempts_module_idx    on public.attempts (module, scenario_id);

-- ---------------------------------------------------------------------
-- Auto-create a profile row whenever a new auth user signs up.
-- display_name / role are pulled from the sign-up metadata if provided.
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)),
    case when new.raw_user_meta_data->>'role' = 'instructor' then 'instructor' else 'student' end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- Row-Level Security. Nothing is readable/writable without a policy.
-- ---------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.attempts enable row level security;

-- helper: is the current user an instructor?
create or replace function public.is_instructor()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'instructor'
  );
$$;

-- profiles: a user can see and edit their own row; instructors can read all.
drop policy if exists "profiles read own"        on public.profiles;
drop policy if exists "profiles read instructor"  on public.profiles;
drop policy if exists "profiles update own"       on public.profiles;
create policy "profiles read own"       on public.profiles for select using (auth.uid() = id);
create policy "profiles read instructor" on public.profiles for select using (public.is_instructor());
create policy "profiles update own"      on public.profiles for update using (auth.uid() = id);

-- attempts: a user can insert and read their own; instructors can read all.
drop policy if exists "attempts insert own"      on public.attempts;
drop policy if exists "attempts read own"        on public.attempts;
drop policy if exists "attempts read instructor" on public.attempts;
create policy "attempts insert own"      on public.attempts for insert with check (auth.uid() = user_id);
create policy "attempts read own"        on public.attempts for select using (auth.uid() = user_id);
create policy "attempts read instructor" on public.attempts for select using (public.is_instructor());

-- =====================================================================
-- To make YOURSELF an instructor after signing up in the app:
--   update public.profiles set role = 'instructor' where id = auth.uid();
-- (run it while logged into the SQL editor as the same account, OR set it
--  by matching your email via the auth.users table.)
-- =====================================================================
