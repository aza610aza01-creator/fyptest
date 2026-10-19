-- =============================================================================
-- AI GYM CLOUD - COMPLETE SUPABASE POSTGRESQL SCHEMA, TRIGGERS, AND RLS
-- Project ID: eprmvrtcpuydxhtzwfep
-- =============================================================================
-- Run this script inside the Supabase SQL Editor.
-- Never expose the service_role key or database password in the Flutter app.

create extension if not exists "pgcrypto";

-- -----------------------------------------------------------------------------
-- UTILITY: UPDATED_AT TIMESTAMP TRIGGER
-- -----------------------------------------------------------------------------
create or replace function public.handle_updated_at()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 5.1 PROFILES TABLE
-- -----------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  age integer check (age is null or (age >= 10 and age <= 120)),
  height_cm numeric(5,2) check (height_cm is null or (height_cm >= 50 and height_cm <= 280)),
  weight_kg numeric(5,2) check (weight_kg is null or (weight_kg >= 20 and weight_kg <= 500)),
  sex text not null default 'prefer_not_to_say'
    check (sex in ('male', 'female', 'other', 'prefer_not_to_say')),
  goal text not null default 'general_health'
    check (goal in ('strength', 'fat_loss', 'muscle', 'general_health')),
  experience_level text not null default 'beginner'
    check (experience_level in ('beginner', 'intermediate', 'advanced')),
  injury_flags text[] not null default '{}',
  equipment_access text not null default 'full_gym'
    check (equipment_access in ('home', 'limited_gym', 'full_gym')),
  unit_system text not null default 'metric'
    check (unit_system in ('metric', 'imperial')),
  language text not null default 'en'
    check (language in ('en', 'zh')),
  timezone text not null default 'Asia/Hong_Kong',
  subscription_plan text not null default 'free'
    check (subscription_plan in ('free', 'premium', 'family', 'team')),
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
  before update on public.profiles
  for each row execute function public.handle_updated_at();

-- Secure trigger to create profile automatically when auth.users receives a new user
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    display_name,
    language,
    unit_system,
    subscription_plan,
    onboarding_completed
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(coalesce(new.email, 'Athlete'), '@', 1)),
    coalesce(new.raw_user_meta_data->>'language', 'en'),
    'metric',
    'free',
    false
  )
  on conflict (id) do update
  set display_name = excluded.display_name,
      updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- 5.2 EXERCISES TABLE
-- -----------------------------------------------------------------------------
create table if not exists public.exercises (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  muscle_group text not null,
  secondary_muscles text[] not null default '{}',
  equipment text not null default 'bodyweight',
  instructions text not null default '',
  cues text[] not null default '{}',
  common_mistakes text[] not null default '{}',
  demo_url text,
  illustration_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_exercises_muscle_group on public.exercises(muscle_group);
create index if not exists idx_exercises_equipment on public.exercises(equipment);
create index if not exists idx_exercises_active on public.exercises(is_active);

-- -----------------------------------------------------------------------------
-- 5.3 ROUTINES TABLE
-- -----------------------------------------------------------------------------
create table if not exists public.routines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  description text not null default '',
  workout_method text not null default 'standard'
    check (workout_method in ('standard', 'superset', 'circuit', 'amrap', 'periodized', 'warmup_mobility')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_routines_user_id on public.routines(user_id);

drop trigger if exists set_routines_updated_at on public.routines;
create trigger set_routines_updated_at
  before update on public.routines
  for each row execute function public.handle_updated_at();

-- -----------------------------------------------------------------------------
-- 5.4 ROUTINE_EXERCISES TABLE
-- -----------------------------------------------------------------------------
create table if not exists public.routine_exercises (
  id uuid primary key default gen_random_uuid(),
  routine_id uuid not null references public.routines(id) on delete cascade,
  exercise_id uuid not null references public.exercises(id) on delete restrict,
  ordering integer not null default 1 check (ordering >= 1),
  target_sets integer not null default 3 check (target_sets >= 1 and target_sets <= 30),
  target_reps integer not null default 10 check (target_reps >= 1 and target_reps <= 500),
  target_weight_kg numeric(6,2) not null default 0 check (target_weight_kg >= 0),
  rest_seconds integer not null default 90 check (rest_seconds >= 0 and rest_seconds <= 1800),
  tempo text not null default '2-0-2-0',
  notes text not null default ''
);

create index if not exists idx_routine_exercises_routine_id on public.routine_exercises(routine_id, ordering);

-- -----------------------------------------------------------------------------
-- 5.5 WORKOUTS TABLE
-- -----------------------------------------------------------------------------
create table if not exists public.workouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  routine_id uuid references public.routines(id) on delete set null,
  title text not null,
  workout_type text not null default 'strength'
    check (workout_type in ('strength', 'hypertrophy', 'cardio', 'mobility', 'warmup', 'cooldown', 'mixed', 'freestyle')),
  started_at timestamptz not null default timezone('utc', now()),
  ended_at timestamptz,
  notes text not null default '',
  synced_at timestamptz default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_workouts_user_started on public.workouts(user_id, started_at desc);

-- -----------------------------------------------------------------------------
-- 5.6 WORKOUT_SETS TABLE
-- -----------------------------------------------------------------------------
create table if not exists public.workout_sets (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid not null references public.workouts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  exercise_id uuid not null references public.exercises(id) on delete restrict,
  set_number integer not null default 1 check (set_number >= 1),
  reps integer not null default 0 check (reps >= 0 and reps <= 1000),
  weight_kg numeric(6,2) not null default 0 check (weight_kg >= 0 and weight_kg <= 2000),
  rpe numeric(3,1) check (rpe is null or (rpe >= 1.0 and rpe <= 10.0)),
  rir integer check (rir is null or (rir >= 0 and rir <= 10)),
  rest_seconds integer not null default 90 check (rest_seconds >= 0 and rest_seconds <= 3600),
  tempo text not null default '',
  set_type text not null default 'standard'
    check (set_type in ('standard', 'warmup', 'superset', 'drop_set', 'circuit', 'amrap')),
  notes text not null default '',
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_workout_sets_workout on public.workout_sets(workout_id, set_number);
create index if not exists idx_workout_sets_user_exercise on public.workout_sets(user_id, exercise_id, created_at desc);

-- -----------------------------------------------------------------------------
-- 5.7 CARDIO_LOGS TABLE
-- -----------------------------------------------------------------------------
create table if not exists public.cardio_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  workout_id uuid references public.workouts(id) on delete cascade,
  cardio_type text not null default 'Running',
  duration_seconds integer not null check (duration_seconds > 0),
  distance_km numeric(6,2) not null default 0 check (distance_km >= 0),
  average_pace text not null default '',
  average_heart_rate integer check (average_heart_rate is null or (average_heart_rate >= 30 and average_heart_rate <= 250)),
  calories_estimated integer not null default 0 check (calories_estimated >= 0),
  intervals jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_cardio_logs_user on public.cardio_logs(user_id, created_at desc);

-- -----------------------------------------------------------------------------
-- 5.8 BODY_MEASUREMENTS TABLE
-- -----------------------------------------------------------------------------
create table if not exists public.body_measurements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  recorded_at timestamptz not null default timezone('utc', now()),
  weight_kg numeric(5,2) check (weight_kg is null or (weight_kg >= 20 and weight_kg <= 500)),
  body_fat_percent numeric(4,1) check (body_fat_percent is null or (body_fat_percent >= 2 and body_fat_percent <= 75)),
  chest_cm numeric(5,1) check (chest_cm is null or (chest_cm >= 30 and chest_cm <= 250)),
  waist_cm numeric(5,1) check (waist_cm is null or (waist_cm >= 30 and waist_cm <= 250)),
  arms_cm numeric(5,1) check (arms_cm is null or (arms_cm >= 10 and arms_cm <= 120)),
  thighs_cm numeric(5,1) check (thighs_cm is null or (thighs_cm >= 20 and thighs_cm <= 150)),
  photo_path text
);

create index if not exists idx_body_measurements_user on public.body_measurements(user_id, recorded_at desc);

-- -----------------------------------------------------------------------------
-- 5.9 HEALTH_LOGS TABLE
-- -----------------------------------------------------------------------------
create table if not exists public.health_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  recorded_date date not null default current_date,
  water_ml integer not null default 0 check (water_ml >= 0 and water_ml <= 20000),
  sleep_hours numeric(4,2) not null default 0 check (sleep_hours >= 0 and sleep_hours <= 24),
  steps integer not null default 0 check (steps >= 0 and steps <= 200000),
  calories integer not null default 0 check (calories >= 0 and calories <= 30000),
  protein_g numeric(5,1) not null default 0 check (protein_g >= 0),
  carbs_g numeric(5,1) not null default 0 check (carbs_g >= 0),
  fat_g numeric(5,1) not null default 0 check (fat_g >= 0),
  resting_heart_rate integer check (resting_heart_rate is null or (resting_heart_rate >= 25 and resting_heart_rate <= 220)),
  unique (user_id, recorded_date)
);

create index if not exists idx_health_logs_user_date on public.health_logs(user_id, recorded_date desc);

-- -----------------------------------------------------------------------------
-- 5.10 CAMERA_DETECTIONS TABLE
-- -----------------------------------------------------------------------------
create table if not exists public.camera_detections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  label text not null,
  confidence numeric(5,4) not null check (confidence >= 0 and confidence <= 1),
  bounding_box jsonb not null default '{}'::jsonb,
  source_width integer not null default 0 check (source_width >= 0),
  source_height integer not null default 0 check (source_height >= 0),
  detected_at timestamptz not null default timezone('utc', now()),
  image_path text
);

create index if not exists idx_camera_detections_user on public.camera_detections(user_id, detected_at desc);

-- -----------------------------------------------------------------------------
-- 5.11 USER_GOALS TABLE
-- -----------------------------------------------------------------------------
create table if not exists public.user_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  goal_type text not null,
  target_value numeric(10,2) not null,
  current_value numeric(10,2) not null default 0,
  target_date date,
  status text not null default 'active'
    check (status in ('active', 'completed', 'paused', 'archived')),
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_user_goals_user on public.user_goals(user_id, status);

-- -----------------------------------------------------------------------------
-- 5.12 BADGES AND USER_BADGES TABLES
-- -----------------------------------------------------------------------------
create table if not exists public.badges (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  title_en text not null,
  title_zh text not null,
  description_en text not null,
  description_zh text not null,
  icon_name text not null default 'emoji_events',
  threshold_value integer not null default 1,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.user_badges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  badge_id uuid not null references public.badges(id) on delete cascade,
  awarded_at timestamptz not null default timezone('utc', now()),
  unique (user_id, badge_id)
);

create index if not exists idx_user_badges_user on public.user_badges(user_id);

-- -----------------------------------------------------------------------------
-- 5.13 OPTIONAL SOCIAL, CHALLENGES, BOOKINGS, AND SUBSCRIPTION ARCHITECTURE
-- (All strictly protected by RLS; private health data is never exposed)
-- -----------------------------------------------------------------------------
create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  friend_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'blocked')),
  created_at timestamptz not null default timezone('utc', now()),
  unique (user_id, friend_id)
);

create table if not exists public.activity_feed (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  author_display_name text not null default 'Athlete',
  summary_text text not null,
  workout_id uuid references public.workouts(id) on delete set null,
  is_public_to_friends boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.kudos (
  id uuid primary key default gen_random_uuid(),
  feed_id uuid not null references public.activity_feed(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  unique (feed_id, user_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  feed_id uuid not null references public.activity_feed(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  author_display_name text not null default 'Athlete',
  body text not null check (char_length(body) <= 500),
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.challenges (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  metric_type text not null default 'workouts_count',
  target_value numeric(10,2) not null default 10,
  start_date date not null default current_date,
  end_date date not null default (current_date + 30),
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.challenge_participants (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  progress_value numeric(10,2) not null default 0,
  joined_at timestamptz not null default timezone('utc', now()),
  unique (challenge_id, user_id)
);

create table if not exists public.subscription_status (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  plan_code text not null default 'free'
    check (plan_code in ('free', 'premium', 'family', 'team')),
  billing_provider text not null default 'none'
    check (billing_provider in ('none', 'google_play', 'apple_iap', 'promo')),
  trial_ends_at timestamptz,
  coaching_credits integer not null default 0 check (coaching_credits >= 0),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.promo_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  discount_percent integer not null default 10 check (discount_percent between 1 and 100),
  is_active boolean not null default true,
  expires_at timestamptz
);

create table if not exists public.trainer_bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  trainer_name text not null,
  session_topic text not null,
  scheduled_at timestamptz not null,
  status text not null default 'requested'
    check (status in ('requested', 'confirmed', 'cancelled', 'completed')),
  notes text not null default '',
  created_at timestamptz not null default timezone('utc', now())
);

-- =============================================================================
-- 6. ROW LEVEL SECURITY (RLS) POLICIES
-- =============================================================================
alter table public.profiles enable row level security;
alter table public.exercises enable row level security;
alter table public.routines enable row level security;
alter table public.routine_exercises enable row level security;
alter table public.workouts enable row level security;
alter table public.workout_sets enable row level security;
alter table public.cardio_logs enable row level security;
alter table public.body_measurements enable row level security;
alter table public.health_logs enable row level security;
alter table public.camera_detections enable row level security;
alter table public.user_goals enable row level security;
alter table public.badges enable row level security;
alter table public.user_badges enable row level security;
alter table public.friendships enable row level security;
alter table public.activity_feed enable row level security;
alter table public.kudos enable row level security;
alter table public.comments enable row level security;
alter table public.challenges enable row level security;
alter table public.challenge_participants enable row level security;
alter table public.subscription_status enable row level security;
alter table public.promo_codes enable row level security;
alter table public.trainer_bookings enable row level security;

-- Profiles: users can only read/insert/update/delete their own profile
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select to authenticated using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert to authenticated with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "profiles_delete_own" on public.profiles;
create policy "profiles_delete_own" on public.profiles
  for delete to authenticated using (auth.uid() = id);

-- Exercises: authenticated users may read active exercise library records
drop policy if exists "exercises_select_active" on public.exercises;
create policy "exercises_select_active" on public.exercises
  for select to authenticated using (is_active = true);

-- Routines: strict owner-only access
drop policy if exists "routines_owner_all" on public.routines;
create policy "routines_owner_all" on public.routines
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Routine Exercises: owner access verified via parent routine
drop policy if exists "routine_exercises_owner_all" on public.routine_exercises;
create policy "routine_exercises_owner_all" on public.routine_exercises
  for all to authenticated
  using (
    exists (
      select 1 from public.routines r
      where r.id = routine_exercises.routine_id and r.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.routines r
      where r.id = routine_exercises.routine_id and r.user_id = auth.uid()
    )
  );

-- Workouts: strict owner-only access
drop policy if exists "workouts_owner_all" on public.workouts;
create policy "workouts_owner_all" on public.workouts
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Workout Sets: strict owner-only access
drop policy if exists "workout_sets_owner_all" on public.workout_sets;
create policy "workout_sets_owner_all" on public.workout_sets
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Cardio Logs: strict owner-only access
drop policy if exists "cardio_logs_owner_all" on public.cardio_logs;
create policy "cardio_logs_owner_all" on public.cardio_logs
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Body Measurements: strict owner-only access
drop policy if exists "body_measurements_owner_all" on public.body_measurements;
create policy "body_measurements_owner_all" on public.body_measurements
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Health Logs: strict owner-only access
drop policy if exists "health_logs_owner_all" on public.health_logs;
create policy "health_logs_owner_all" on public.health_logs
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Camera Detections: private to their owner
drop policy if exists "camera_detections_owner_all" on public.camera_detections;
create policy "camera_detections_owner_all" on public.camera_detections
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- User Goals: strict owner-only access
drop policy if exists "user_goals_owner_all" on public.user_goals;
create policy "user_goals_owner_all" on public.user_goals
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Badges catalog: readable by authenticated users
drop policy if exists "badges_select_authenticated" on public.badges;
create policy "badges_select_authenticated" on public.badges
  for select to authenticated using (true);

-- User Badges: strict owner-only access
drop policy if exists "user_badges_owner_all" on public.user_badges;
create policy "user_badges_owner_all" on public.user_badges
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Friendships: users can see and manage their own friendship links
drop policy if exists "friendships_owner_all" on public.friendships;
create policy "friendships_owner_all" on public.friendships
  for all to authenticated
  using (auth.uid() = user_id or auth.uid() = friend_id)
  with check (auth.uid() = user_id);

-- Activity Feed: owners manage own posts; only explicitly shared workout posts visible
drop policy if exists "activity_feed_select" on public.activity_feed;
create policy "activity_feed_select" on public.activity_feed
  for select to authenticated
  using (auth.uid() = user_id or is_public_to_friends = true);

drop policy if exists "activity_feed_write_own" on public.activity_feed;
create policy "activity_feed_write_own" on public.activity_feed
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Kudos & Comments
drop policy if exists "kudos_select" on public.kudos;
create policy "kudos_select" on public.kudos
  for select to authenticated using (true);

drop policy if exists "kudos_write_own" on public.kudos;
create policy "kudos_write_own" on public.kudos
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "comments_select" on public.comments;
create policy "comments_select" on public.comments
  for select to authenticated using (true);

drop policy if exists "comments_write_own" on public.comments;
create policy "comments_write_own" on public.comments
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Challenges & Participants
drop policy if exists "challenges_select_active" on public.challenges;
create policy "challenges_select_active" on public.challenges
  for select to authenticated using (is_active = true);

drop policy if exists "challenge_participants_owner_all" on public.challenge_participants;
create policy "challenge_participants_owner_all" on public.challenge_participants
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Subscription Status, Promo Codes & Trainer Bookings
drop policy if exists "subscription_status_owner_all" on public.subscription_status;
create policy "subscription_status_owner_all" on public.subscription_status
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "promo_codes_select_active" on public.promo_codes;
create policy "promo_codes_select_active" on public.promo_codes
  for select to authenticated using (is_active = true);

drop policy if exists "trainer_bookings_owner_all" on public.trainer_bookings;
create policy "trainer_bookings_owner_all" on public.trainer_bookings
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- =============================================================================
-- AI GYM CLOUD - SEED DATA FOR EXERCISES, BADGES, AND CHALLENGES
-- =============================================================================

insert into public.exercises (
  name,
  muscle_group,
  secondary_muscles,
  equipment,
  instructions,
  cues,
  common_mistakes,
  demo_url,
  illustration_url,
  is_active
)
values
  (
    'Squat',
    'Legs',
    array['Glutes', 'Core', 'Lower Back'],
    'Barbell',
    'Stand with feet shoulder-width apart, brace your core, hinge hips back and bend knees to lower until thighs are parallel to the floor, then drive through mid-foot to stand.',
    array['Chest proud and neutral spine', 'Knees track over toes', 'Brace 360 degrees around core'],
    array['Knees caving inward (valgus)', 'Rounding lower back at the bottom', 'Lifting heels off the floor'],
    'https://example.com/demos/squat',
    'assets/illustrations/squat.png',
    true
  ),
  (
    'Push-up',
    'Chest',
    array['Triceps', 'Anterior Deltoids', 'Core'],
    'Bodyweight',
    'Start in a high plank with hands slightly wider than shoulders. Lower your chest cleanly toward the floor while keeping elbows at a 45-degree angle, then press back up.',
    array['Maintain a rigid plank line', 'Tuck elbows at 45 degrees', 'Full lockout at the top'],
    array['Sagging hips or lumbar hyperextension', 'Flaring elbows to 90 degrees', 'Half repetitions'],
    'https://example.com/demos/pushup',
    'assets/illustrations/pushup.png',
    true
  ),
  (
    'Deadlift',
    'Back',
    array['Hamstrings', 'Glutes', 'Forearms', 'Core'],
    'Barbell',
    'Stand with mid-foot under the barbell, grip just outside legs, pull slack out of the bar, brace lats and core, and drive the floor away until hips and knees lock out.',
    array['Keep the bar close to shins', 'Engage lats (protect armpits)', 'Hinge at the hips on descent'],
    array['Rounding lumbar spine', 'Jerking the bar off the floor', 'Hyperextending the back at lockout'],
    'https://example.com/demos/deadlift',
    'assets/illustrations/deadlift.png',
    true
  ),
  (
    'Bench Press',
    'Chest',
    array['Triceps', 'Anterior Deltoids'],
    'Barbell',
    'Lie on the flat bench with eyes under the bar, retract shoulder blades, plant feet firmly, lower the bar with control to lower chest, and press upward slightly back toward the rack.',
    array['Retract and depress scapula', 'Drive feet into floor for stability', 'Wrists stacked straight over elbows'],
    array['Bouncing bar off the chest', 'Lifting hips off the bench', 'Bent wrists under load'],
    'https://example.com/demos/bench-press',
    'assets/illustrations/bench_press.png',
    true
  ),
  (
    'Shoulder Press',
    'Shoulders',
    array['Triceps', 'Upper Chest', 'Core'],
    'Dumbbell',
    'Sit or stand tall with dumbbells at shoulder height, brace abs and glutes, press weights overhead until arms are aligned with ears, and lower with control.',
    array['Squeeze glutes and ribs down', 'Press vertically in a controlled arc', 'Keep head neutral'],
    array['Excessive lower back arch', 'Using leg drive when performing strict press', 'Shortening range of motion'],
    'https://example.com/demos/shoulder-press',
    'assets/illustrations/shoulder_press.png',
    true
  ),
  (
    'Bicep Curl',
    'Arms',
    array['Forearms', 'Brachialis'],
    'Dumbbell',
    'Stand tall holding dumbbells with palms facing forward, keep elbows pinned by your sides, curl weights toward shoulders, squeeze biceps, and lower slowly.',
    array['Elbows stay stationary at ribs', 'Supinate wrists fully at top', 'Control the 2-second eccentric'],
    array['Swinging torso for momentum', 'Moving elbows forward', 'Dropping the weight rapidly'],
    'https://example.com/demos/bicep-curl',
    'assets/illustrations/bicep_curl.png',
    true
  ),
  (
    'Plank',
    'Core',
    array['Shoulders', 'Glutes'],
    'Bodyweight',
    'Support your body on forearms and toes with elbows directly under shoulders. Maintain a straight line from head to heels while breathing steadily.',
    array['Push forearms actively into floor', 'Posteriorly tilt pelvis slightly', 'Breathe behind the shield'],
    array['Hips dropping toward floor', 'Looking up and straining neck', 'Holding breath'],
    'https://example.com/demos/plank',
    'assets/illustrations/plank.png',
    true
  ),
  (
    'Running',
    'Cardio',
    array['Quadriceps', 'Calves', 'Hamstrings', 'Cardiovascular'],
    'Treadmill / Outdoor',
    'Maintain an upright posture with a slight forward lean from the ankles, land softly under your center of mass, and keep a steady cadence and rhythmic breathing.',
    array['Relax shoulders and hands', 'Quick light cadence', 'Land under hips, not ahead'],
    array['Overstriding with heavy heel strike', 'Tensing upper body', 'Starting intervals without warm-up'],
    'https://example.com/demos/running',
    'assets/illustrations/running.png',
    true
  ),
  (
    'Cycling',
    'Cardio',
    array['Quadriceps', 'Glutes', 'Calves', 'Cardiovascular'],
    'Stationary Bike / Road',
    'Set saddle height so knee retains a slight bend at the bottom of the pedal stroke. Pedal smoothly through full circles while keeping upper body relaxed.',
    array['Smooth 360-degree pedal stroke', 'Neutral spine and light grip', 'Maintain target RPM cadence'],
    array['Saddle too low causing knee strain', 'Rocking hips side to side', 'Locking elbows rigidly'],
    'https://example.com/demos/cycling',
    'assets/illustrations/cycling.png',
    true
  )
on conflict (name) do update
set muscle_group = excluded.muscle_group,
    secondary_muscles = excluded.secondary_muscles,
    equipment = excluded.equipment,
    instructions = excluded.instructions,
    cues = excluded.cues,
    common_mistakes = excluded.common_mistakes,
    is_active = true;

-- Seed default badges
insert into public.badges (code, title_en, title_zh, description_en, description_zh, icon_name, threshold_value)
values
  ('first_workout', 'First Session', '首次訓練', 'Complete your first logged workout.', '完成您的第一次訓練記錄。', 'fitness_center', 1),
  ('streak_3', '3-Day Streak', '連續3天訓練', 'Train on 3 consecutive days.', '連續3天完成訓練。', 'local_fire_department', 3),
  ('streak_7', '7-Day Streak', '連續7天訓練', 'Maintain a 7-day training streak.', '保持連續7天訓練紀錄。', 'bolt', 7),
  ('volume_10k', '10,000 kg Club', '萬公斤俱樂部', 'Accumulate 10,000 kg of total training volume.', '累積達到 10,000 公斤總訓練容量。', 'workspace_premium', 10000),
  ('vision_scanner', 'AI Vision Pioneer', 'AI 視覺先鋒', 'Log your first ML Kit camera object detection.', '完成首次 ML Kit 相機物件偵測記錄。', 'center_focus_strong', 1)
on conflict (code) do nothing;

-- Seed default community challenges
insert into public.challenges (title, description, metric_type, target_value, start_date, end_date, is_active)
values
  ('30-Day Consistency Challenge', 'Complete 12 structured workouts inside 30 days.', 'workouts_count', 12, current_date, current_date + 30, true),
  ('50 km Cardio Endurance', 'Log 50 km across Running or Cycling sessions.', 'distance_km', 50, current_date, current_date + 30, true);
