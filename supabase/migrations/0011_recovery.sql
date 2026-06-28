-- =============================================================================
-- 유연한 회복(Recovery): 미준수 감지·처리 이벤트 기록.
-- 비난이 아니라 회복을 돕기 위한 로그 — 통계/반복 안내에 활용.
-- =============================================================================
create table if not exists public.recovery_events (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  -- 감지 유형: violation(식단위반) / low_completion(저달성) /
  --           fast_cancel(단식취소) / gap(연속 미기록)
  kind        text not null
    check (kind in ('violation', 'low_completion', 'fast_cancel', 'gap')),
  -- 처리 방식: extend(하루 연장) / pause(일시정지) / restart(오늘 재시작) /
  --           coach(AI 코칭) / dismiss(닫기)
  resolution  text
    check (resolution is null or
           resolution in ('extend', 'pause', 'restart', 'coach', 'dismiss')),
  event_date  date not null default current_date,
  created_at  timestamptz not null default now()
);

alter table public.recovery_events enable row level security;

create policy "recovery_events_own" on public.recovery_events
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index if not exists idx_recovery_events_user
  on public.recovery_events (user_id, created_at desc);
