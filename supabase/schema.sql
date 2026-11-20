-- Supabase SQL Editor에서 실행하세요. PostgreSQL 15 이상이 필요합니다.
-- 같은 파일을 다시 실행해도 기존 점수는 유지됩니다.
-- 정적 클라이언트가 제출한 점수를 저장하므로 점수 진위나 닉네임 소유권은 검증하지 않습니다.

begin;

create table if not exists public.scores (
  id uuid primary key default gen_random_uuid(),
  nickname text not null,
  score integer not null,
  created_at timestamptz not null default now(),
  constraint scores_nickname_length check (char_length(nickname) between 1 and 12),
  constraint scores_score_range check (score between 0 and 1000)
);

create index if not exists scores_nickname_best_idx
  on public.scores (nickname, score desc, created_at asc, id asc);

alter table public.scores enable row level security;

-- Supabase의 기본 권한과 무관하게 공개 클라이언트 권한을 명시합니다.
revoke all privileges on table public.scores from public, anon, authenticated;
grant usage on schema public to anon;
grant select on table public.scores to anon;
grant insert (nickname, score) on table public.scores to anon;

drop policy if exists scores_anon_select on public.scores;
create policy scores_anon_select
  on public.scores for select to anon
  using (true);

drop policy if exists scores_anon_insert on public.scores;
create policy scores_anon_insert
  on public.scores for insert to anon
  with check (
    char_length(nickname) between 1 and 12
    and score between 0 and 1000
  );

-- UPDATE / DELETE 권한과 정책은 제공하지 않습니다.
-- id와 created_at은 INSERT 허용 컬럼에서 제외하여 DB 기본값만 사용합니다.

-- 닉네임별 최고 점수 1건. 동점이면 먼저 등록된 기록을 사용합니다.
-- security_invoker로 원본 테이블의 권한과 RLS를 그대로 적용합니다.
create or replace view public.leaderboard
  with (security_invoker = true)
as
select distinct on (nickname) id, nickname, score, created_at
from public.scores
order by nickname, score desc, created_at asc, id asc;

revoke all privileges on table public.leaderboard from public, anon, authenticated;
grant select on table public.leaderboard to anon;

comment on view public.leaderboard is
  '닉네임별 최고 점수. TOP 10 조회 시 score DESC, created_at ASC, id ASC 순서와 LIMIT 10을 적용합니다.';

-- 한국 시각 오늘 00:00 이상, 다음 날 00:00 미만의 기록만 집계합니다.
-- created_at 컬럼을 변환하지 않아 날짜 범위 조회에 인덱스를 사용할 수 있습니다.
create index if not exists scores_created_at_idx
  on public.scores (created_at);

create or replace view public.daily_leaderboard
  with (security_invoker = true)
as
select distinct on (nickname) id, nickname, score, created_at
from public.scores
where created_at >= (
    date_trunc('day', now() at time zone 'Asia/Seoul')
    at time zone 'Asia/Seoul'
  )
  and created_at < (
    (date_trunc('day', now() at time zone 'Asia/Seoul') + interval '1 day')
    at time zone 'Asia/Seoul'
  )
order by nickname, score desc, created_at asc, id asc;

revoke all privileges on table public.daily_leaderboard from public, anon, authenticated;
grant select on table public.daily_leaderboard to anon;

comment on view public.daily_leaderboard is
  'Asia/Seoul 오늘의 닉네임별 최고 점수. 기록 삭제 없이 조회 시 날짜를 계산합니다. TOP 10은 score DESC, created_at ASC, id ASC 및 LIMIT 10으로 조회합니다.';

notify pgrst, 'reload schema';

commit;
