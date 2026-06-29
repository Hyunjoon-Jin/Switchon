-- 식단 공유 포스트 지원: community_posts 에 meal_data JSONB 컬럼 추가.
-- kind = 'meal_share' 로 구분하며, meal_data 에 끼니·음식 태그·AI 점수 등을 담는다.

ALTER TABLE community_posts
  ADD COLUMN IF NOT EXISTS meal_data JSONB;

-- Realtime 을 활성화(이미 켜져 있다면 NOOP).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND tablename = 'community_posts'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE community_posts;
  END IF;
END
$$;

COMMENT ON COLUMN community_posts.meal_data IS
  'kind=meal_share 일 때 사용. {slot, slotLabel, foodTags, aiVerdict, aiScore, aiCalories, aiCarbsG, aiProteinG, aiFatG, aiFoods, memo, photoUrl}';
