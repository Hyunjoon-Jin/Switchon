-- =============================================================================
-- 단식 세션 (14h / 24h 타이머)
-- =============================================================================
create table public.fasting_sessions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  started_at   timestamptz not null default now(),
  target_hours int  not null check (target_hours in (14, 24)),
  ended_at     timestamptz,
  status       text not null default 'active'
                 check (status in ('active', 'completed', 'canceled')),
  created_at   timestamptz not null default now()
);

create index idx_fasting_user_started
  on public.fasting_sessions (user_id, started_at desc);

-- 사용자당 활성 단식은 1개만 (부분 유니크 인덱스)
create unique index uniq_active_fasting_per_user
  on public.fasting_sessions (user_id)
  where status = 'active';

alter table public.fasting_sessions enable row level security;

create policy "fasting_all_own" on public.fasting_sessions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
