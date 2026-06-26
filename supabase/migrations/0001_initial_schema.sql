-- =============================================================================
-- 스위치온 다이어트 — 초기 스키마 (P0)
-- 모든 사용자 데이터 테이블은 RLS로 보호: user_id = auth.uid()
-- =============================================================================

-- ----------------------------------------------------------------------------
-- 공통: updated_at 자동 갱신 트리거 함수
-- ----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ----------------------------------------------------------------------------
-- profiles : 사용자 기본 정보 + 프로그램 진행 상태
-- ----------------------------------------------------------------------------
create table public.profiles (
  id                      uuid primary key references auth.users (id) on delete cascade,
  start_date              date,
  current_week            int  not null default 1 check (current_week between 1 and 4),
  current_day             int  not null default 1 check (current_day between 1 and 7),
  -- 일시정지·재개 방식: paused 상태에서는 일차가 자동으로 밀리지 않음
  status                  text not null default 'active'
                            check (status in ('active', 'paused', 'completed')),
  -- 체중 강박 방지: 목표는 수치 강요 대신 자유 서술, 체중 추적은 선택사항
  goal                    text,
  track_weight            boolean not null default false,
  -- 나이 게이트 (만 19세 미만 사용 제한 안내용)
  birth_year              int check (birth_year between 1900 and 2100),
  age_verified            boolean not null default false,
  -- 온보딩 안전 고지 동의 시각 (의료 조언 아님 / 의사 상담 권고)
  safety_acknowledged_at  timestamptz,
  onboarding_completed_at timestamptz,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- 회원가입 시 빈 프로필 자동 생성
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ----------------------------------------------------------------------------
-- progress : 주차별 단계/분기 상태
-- ----------------------------------------------------------------------------
create table public.progress (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  week_no       int  not null check (week_no between 1 and 4),
  stage         text not null,   -- 예: w1_shake_only / w1_lunch_added / w2 / w3_4
  -- (2차) 근육량 회복 분기 결과
  branch_result text check (branch_result in ('repeat', 'advance', 'maintain')),
  started_at    timestamptz not null default now(),
  completed_at  timestamptz,
  created_at    timestamptz not null default now(),
  unique (user_id, week_no)
);

-- ----------------------------------------------------------------------------
-- daily_logs : 하루 1행 — 체크리스트(물·수면·단식·운동) + 달성률
-- ----------------------------------------------------------------------------
create table public.daily_logs (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users (id) on delete cascade,
  log_date        date not null,
  water_ml        int     not null default 0 check (water_ml >= 0),
  water_done      boolean not null default false,
  sleep_hours     numeric(3, 1) check (sleep_hours >= 0 and sleep_hours <= 24),
  fasting_done    boolean not null default false,
  exercise_done   boolean not null default false,
  completion_rate numeric(4, 3) not null default 0    -- 0.000 ~ 1.000
                    check (completion_rate >= 0 and completion_rate <= 1),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (user_id, log_date)
);

create trigger trg_daily_logs_updated_at
  before update on public.daily_logs
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- meal_logs : 식단 기록 (셰이크 카운터 / 식사 사진·메모)
-- ----------------------------------------------------------------------------
create table public.meal_logs (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users (id) on delete cascade,
  logged_at      timestamptz not null default now(),
  type           text not null check (type in ('shake', 'meal')),
  shake_count    int  not null default 0 check (shake_count >= 0),
  photo_url      text,
  memo           text,
  -- (2차) 규칙 위반 감지: 사용자가 선택한 음식 태그 + 현재 주차 규칙 대조 결과
  food_tags      text[] not null default '{}',
  rule_violation boolean,
  created_at     timestamptz not null default now()
);

create index idx_meal_logs_user_time on public.meal_logs (user_id, logged_at desc);
create index idx_daily_logs_user_date on public.daily_logs (user_id, log_date desc);

-- ----------------------------------------------------------------------------
-- stage_rules : 주차별 미션/허용·금지 식품 (정적 참조 데이터, 사용자 무관)
--   읽기 전용 — 인증 사용자 누구나 조회 가능, 쓰기는 서비스 역할만.
-- ----------------------------------------------------------------------------
create table public.stage_rules (
  id              text primary key,           -- 예: w1_shake_only
  week_no         int  not null check (week_no between 1 and 4),
  day_from        int  not null check (day_from between 1 and 7),
  day_to          int  not null check (day_to between 1 and 7),
  title           text not null,
  mission         jsonb not null default '[]'::jsonb,   -- 오늘의 미션 항목 배열
  allowed_foods   jsonb not null default '[]'::jsonb,
  forbidden_foods jsonb not null default '[]'::jsonb,
  notes           text,
  sort_order      int  not null default 0
);

-- =============================================================================
-- RLS
-- =============================================================================
alter table public.profiles    enable row level security;
alter table public.progress    enable row level security;
alter table public.daily_logs  enable row level security;
alter table public.meal_logs   enable row level security;
alter table public.stage_rules enable row level security;

-- profiles: 본인 행만
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- 본인 소유(user_id) 행만 — progress / daily_logs / meal_logs 공통 패턴
create policy "progress_all_own" on public.progress
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "daily_logs_all_own" on public.daily_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "meal_logs_all_own" on public.meal_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- stage_rules: 인증 사용자 읽기 전용 (쓰기 정책 없음 → service_role만 변경 가능)
create policy "stage_rules_read_authenticated" on public.stage_rules
  for select using (auth.role() = 'authenticated');

-- =============================================================================
-- Storage : 식단 사진 버킷 (사용자별 폴더 격리)
-- =============================================================================
insert into storage.buckets (id, name, public)
values ('meal-photos', 'meal-photos', false)
on conflict (id) do nothing;

create policy "meal_photos_rw_own_folder" on storage.objects
  for all
  using (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
