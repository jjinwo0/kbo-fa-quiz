-- 이미 schema.sql을 실행한 Supabase 프로젝트의 SQL Editor에서 실행하세요.
-- 신규 프로젝트는 schema.sql만 실행하면 됩니다. PostgreSQL 15 이상이 필요합니다.
-- 재실행 가능하며 기존 점수와 전체 랭킹을 유지합니다. 매일 초기화하는 작업은 없습니다.

begin;

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
