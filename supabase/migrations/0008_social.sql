-- =============================================================================
-- 소셜 고도화: 공개 통계(opt-in) + 성과 카드 게시글
-- =============================================================================

-- 공개용 통계 요약 (원시 기록은 비공개 유지, 이 요약만 opt-in 공개)
create table public.public_stats (
  user_id          uuid primary key references auth.users (id) on delete cascade,
  display_name     text,
  current_week     int,
  avg_completion   numeric(4, 3) not null default 0,
  fasting_completed int not null default 0,
  current_streak   int not null default 0,
  is_public        boolean not null default false,
  updated_at       timestamptz not null default now()
);

alter table public.public_stats enable row level security;

-- 공개(is_public)된 행은 인증 사용자 누구나 읽기, 본인 행은 항상.
create policy "public_stats_read" on public.public_stats
  for select using (is_public = true or auth.uid() = user_id);
create policy "public_stats_write_own" on public.public_stats
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index idx_public_stats_week
  on public.public_stats (current_week)
  where is_public = true;

-- 성과 카드 게시글: community_posts 에 종류/성과 데이터 추가
alter table public.community_posts
  add column if not exists kind text not null default 'normal'
    check (kind in ('normal', 'achievement')),
  add column if not exists achievement jsonb;
