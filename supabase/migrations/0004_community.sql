-- =============================================================================
-- 3차 커뮤니티 + 원격 푸시 토대
-- =============================================================================

-- 표시용 닉네임 (게시글에 비정규화 저장하므로 타 사용자 프로필 노출 없음)
alter table public.profiles
  add column if not exists display_name text;

-- ----------------------------------------------------------------------------
-- community_posts : 같은 주차 그룹 피드 (group_week 로 분리)
-- ----------------------------------------------------------------------------
create table public.community_posts (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  author_name text not null,
  group_week  int  not null check (group_week between 1 and 4),
  content     text not null check (char_length(content) <= 1000),
  photo_url   text,
  created_at  timestamptz not null default now()
);
create index idx_posts_week_time
  on public.community_posts (group_week, created_at desc);

create table public.community_cheers (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.community_posts (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);
create index idx_cheers_post on public.community_cheers (post_id);

create table public.community_comments (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references public.community_posts (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  author_name text not null,
  content     text not null check (char_length(content) <= 500),
  created_at  timestamptz not null default now()
);
create index idx_comments_post on public.community_comments (post_id, created_at);

-- ----------------------------------------------------------------------------
-- device_tokens : 원격 푸시(FCM) 대상 토큰 — Edge Function 이 참조
-- ----------------------------------------------------------------------------
create table public.device_tokens (
  user_id    uuid not null references auth.users (id) on delete cascade,
  token      text not null,
  platform   text not null check (platform in ('ios', 'android')),
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);

-- =============================================================================
-- RLS — 커뮤니티는 인증 사용자에게 공개(읽기), 작성/삭제는 본인만
-- =============================================================================
alter table public.community_posts    enable row level security;
alter table public.community_cheers    enable row level security;
alter table public.community_comments  enable row level security;
alter table public.device_tokens       enable row level security;

create policy "posts_read_auth" on public.community_posts
  for select using (auth.role() = 'authenticated');
create policy "posts_insert_own" on public.community_posts
  for insert with check (auth.uid() = user_id);
create policy "posts_delete_own" on public.community_posts
  for delete using (auth.uid() = user_id);

create policy "cheers_read_auth" on public.community_cheers
  for select using (auth.role() = 'authenticated');
create policy "cheers_write_own" on public.community_cheers
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "comments_read_auth" on public.community_comments
  for select using (auth.role() = 'authenticated');
create policy "comments_insert_own" on public.community_comments
  for insert with check (auth.uid() = user_id);
create policy "comments_delete_own" on public.community_comments
  for delete using (auth.uid() = user_id);

create policy "tokens_rw_own" on public.device_tokens
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- =============================================================================
-- Storage : 커뮤니티 사진 (공개 읽기 버킷, 쓰기는 본인 폴더)
-- =============================================================================
insert into storage.buckets (id, name, public)
values ('community-photos', 'community-photos', true)
on conflict (id) do nothing;

create policy "community_photos_read" on storage.objects
  for select using (bucket_id = 'community-photos');

create policy "community_photos_write_own" on storage.objects
  for insert
  with check (
    bucket_id = 'community-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
