-- =============================================================================
-- 식단 기록 상세화: 끼니 구분 + 다중 사진
-- (memo 는 text 라 길이 제한 없음 — UI 제한만 완화)
-- =============================================================================
alter table public.meal_logs
  add column if not exists meal_slot text
    check (meal_slot in ('breakfast', 'lunch', 'dinner', 'snack')),
  add column if not exists photo_urls text[] not null default '{}';
