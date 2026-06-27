-- =============================================================================
-- 수면 시각 입력: 잠든 시각 / 일어난 시각 (자정 넘김은 앱에서 계산)
-- sleep_hours 는 그대로 유지(달성률 계산용) — 두 시각에서 산출해 채움.
-- =============================================================================
alter table public.daily_logs
  add column if not exists sleep_start time,
  add column if not exists sleep_end   time;
