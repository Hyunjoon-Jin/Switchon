-- =============================================================================
-- AI 영양 추정: 칼로리 + 3대 영양소(탄·단·지) + 신뢰도.
-- 사진/메뉴 기반 추정치이며 정확한 값이 아님(앱에 추정치임을 명시).
-- =============================================================================
alter table public.meal_logs
  add column if not exists ai_calories int
    check (ai_calories is null or ai_calories >= 0),
  add column if not exists ai_carbs_g int
    check (ai_carbs_g is null or ai_carbs_g >= 0),
  add column if not exists ai_protein_g int
    check (ai_protein_g is null or ai_protein_g >= 0),
  add column if not exists ai_fat_g int
    check (ai_fat_g is null or ai_fat_g >= 0),
  add column if not exists ai_confidence text
    check (ai_confidence is null or ai_confidence in ('high', 'medium', 'low'));
