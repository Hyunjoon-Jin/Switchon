-- =============================================================================
-- AI 식단 판독: 음식 사진을 Claude(비전)로 분석한 결과를 식사 기록에 저장.
--
-- 분석은 사용자가 식사 상세에서 "AI 분석" 버튼을 눌렀을 때만 수행되며,
-- 결과(점수/판정/피드백/조절제안)는 Edge Function(analyze-meal)이 서비스 롤로
-- 이 컬럼들에 직접 기록합니다. ai_verdict 가 'violation' 이면 rule_violation 을
-- true 로 덮어써서(②B) 통계·배지에 반영합니다.
-- =============================================================================
alter table public.meal_logs
  add column if not exists ai_score int
    check (ai_score is null or (ai_score between 0 and 100)),
  add column if not exists ai_verdict text
    check (ai_verdict is null or ai_verdict in ('fit', 'caution', 'violation')),
  add column if not exists ai_foods text,
  add column if not exists ai_feedback text,
  add column if not exists ai_suggestion text,
  add column if not exists ai_analyzed_at timestamptz;
