-- verified-ranking.sql 다음에 Supabase SQL Editor에서 한 번 실행하세요. 재실행해도 안전합니다.
-- 오늘의 도전 문항당 제한 시간: 10초(+네트워크 여유 3초). 초과한 답은 0점입니다.
-- 문제는 한 문항씩 공개하며, 공개 시각은 서버가 기록합니다. 홈으로 나가도 시간은 흐릅니다.

begin;

alter table quiz_private.quiz_attempts add column if not exists question_started_at timestamptz;

-- deck 전체 대신 지금 공개된 문항(current)과 남은 시간만 돌려줍니다.
create or replace function quiz_private.attempt_state(p_attempt_id uuid, p_user_id uuid)
returns jsonb language sql volatile security definer set search_path = '' as $fn$
  select pg_catalog.jsonb_build_object(
    'attempt_id', a.id,
    'challenge_date', pg_catalog.to_char(a.challenge_date, 'YYYY-MM-DD'),
    'next_index', a.next_index,
    'total', a.total,
    'completed', a.next_index = 10,
    'published', a.published_at is not null,
    'nickname', p.nickname,
    'user_id', a.user_id,
    'time_limit_ms', 10000,
    'current', (
      select pg_catalog.jsonb_build_object('question_id', q.id)
        || (q.payload - array['amount', 'guarantee', 'option', 'source']::text[])
      from quiz_private.quiz_questions q
      where a.next_index < 10 and a.question_started_at is not null
        and q.id = a.deck_ids[a.next_index + 1]
    ),
    'remaining_ms', case when a.next_index < 10 and a.question_started_at is not null then
      greatest(0, pg_catalog.floor(extract(epoch from
        (a.question_started_at + interval '10 seconds' - pg_catalog.clock_timestamp())) * 1000))::integer
    end,
    'answers', a.answers
  )
  from quiz_private.quiz_attempts a
  left join public.quiz_profiles p on p.user_id = a.user_id
  where a.id = p_attempt_id and a.user_id = p_user_id;
$fn$;

-- 오늘 시도를 만들거나 불러오고, 현재 문항을 공개합니다. 이미 공개된 문항의 시각은 바꾸지 않습니다.
create or replace function public.quiz_daily_start()
returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare
  v_user_id uuid := auth.uid();
  v_today date := (pg_catalog.now() at time zone 'Asia/Seoul')::date;
  v_attempt_id uuid;
  v_deck integer[];
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'QUIZ_AUTH_REQUIRED';
  end if;
  perform quiz_private.touch_limit(v_user_id);
  select id into v_attempt_id from quiz_private.quiz_attempts
    where user_id = v_user_id and challenge_date = v_today;
  if v_attempt_id is null then
    -- 한국 날짜 기준 전원 같은 10문제. name+pos로 같은 선수의 다른 계약은 제외합니다.
    with ranked as (
      select q.id,
        pg_catalog.md5(pg_catalog.to_char(v_today, 'YYYY-MM-DD') || ':' || q.id::text) as sort_key,
        pg_catalog.row_number() over (
          partition by q.payload ->> 'name', q.payload ->> 'pos'
          order by pg_catalog.md5(pg_catalog.to_char(v_today, 'YYYY-MM-DD') || ':' || q.id::text), q.id
        ) as occurrence
      from quiz_private.quiz_questions q
    ), chosen as (
      select id, sort_key from ranked where occurrence = 1 order by sort_key, id limit 10
    )
    select pg_catalog.array_agg(id order by sort_key, id) into v_deck from chosen;
    if pg_catalog.cardinality(v_deck) is distinct from 10 then
      raise exception using errcode = 'P0001', message = 'QUIZ_DATA_NOT_READY';
    end if;
    insert into quiz_private.quiz_attempts (user_id, challenge_date, deck_ids)
    values (v_user_id, v_today, v_deck)
    on conflict (user_id, challenge_date) do update set user_id = excluded.user_id
    returning id into v_attempt_id;
  end if;
  update quiz_private.quiz_attempts set question_started_at = pg_catalog.clock_timestamp()
    where id = v_attempt_id and next_index < 10 and question_started_at is null;
  return quiz_private.attempt_state(v_attempt_id, v_user_id);
end
$fn$;

create or replace function public.quiz_daily_answer(
  p_attempt_id uuid, p_question_index integer, p_guess numeric
)
returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare
  v_user_id uuid := auth.uid();
  v_today date := (pg_catalog.now() at time zone 'Asia/Seoul')::date;
  v_attempt quiz_private.quiz_attempts%rowtype;
  v_player jsonb;
  v_answer numeric;
  v_points integer;
  v_timed_out boolean;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'QUIZ_AUTH_REQUIRED';
  end if;
  perform quiz_private.touch_limit(v_user_id);
  if p_question_index is null or p_question_index < 0 or p_question_index > 9 then
    raise exception using errcode = '22023', message = 'QUIZ_INVALID_INDEX';
  end if;
  select * into v_attempt from quiz_private.quiz_attempts
    where id = p_attempt_id and user_id = v_user_id for update;
  if not found then
    raise exception using errcode = '42501', message = 'QUIZ_ATTEMPT_NOT_FOUND';
  end if;

  -- 응답이 유실된 같은 입력은 복구하고, 이미 채점한 답의 변경은 거부합니다.
  if p_question_index < v_attempt.next_index then
    if (v_attempt.answers -> p_question_index ->> 'guess')::numeric is distinct from p_guess then
      raise exception using errcode = '22023', message = 'QUIZ_ANSWER_CONFLICT';
    end if;
    return quiz_private.attempt_state(v_attempt.id, v_user_id);
  end if;
  if v_attempt.challenge_date <> v_today then
    raise exception using errcode = '22023', message = 'QUIZ_ATTEMPT_EXPIRED';
  end if;
  if p_question_index <> v_attempt.next_index then
    raise exception using errcode = '22023', message = 'QUIZ_OUT_OF_ORDER';
  end if;
  if v_attempt.question_started_at is null then
    raise exception using errcode = '22023', message = 'QUIZ_QUESTION_NOT_OPEN';
  end if;
  if p_guess is null or p_guess::text in ('NaN', 'Infinity', '-Infinity')
     or p_guess < 0 or p_guess > 1000000 then
    raise exception using errcode = '22023', message = 'QUIZ_INVALID_GUESS';
  end if;
  select payload into v_player from quiz_private.quiz_questions
    where id = v_attempt.deck_ids[p_question_index + 1];
  v_answer := (v_player ->> 'amount')::numeric;
  if v_answer is null or v_answer <= 0 then
    raise exception using errcode = 'P0001', message = 'QUIZ_DATA_NOT_READY';
  end if;
  -- 10초 제한 + 네트워크 지연 여유 3초
  v_timed_out := pg_catalog.clock_timestamp() > v_attempt.question_started_at + interval '13 seconds';
  v_points := case when v_timed_out then 0
    else greatest(0, pg_catalog.round(100 - pg_catalog.abs(p_guess - v_answer) / v_answer * 100))::integer end;
  update quiz_private.quiz_attempts set
    answers = answers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'question_id', v_attempt.deck_ids[p_question_index + 1],
      'guess', p_guess, 'points', v_points, 'timed_out', v_timed_out, 'player', v_player
    )),
    next_index = next_index + 1,
    total = total + v_points,
    question_started_at = null,
    completed_at = case when next_index = 9 then pg_catalog.now() else completed_at end
  where id = v_attempt.id;
  return quiz_private.attempt_state(v_attempt.id, v_user_id);
end
$fn$;

-- create or replace는 기존 권한을 유지하지만, 다른 환경에서 실행할 때를 위해 다시 명시합니다.
revoke all privileges on all functions in schema quiz_private from public, anon, authenticated;
revoke all privileges on function public.quiz_daily_start() from public, anon, authenticated;
revoke all privileges on function public.quiz_daily_answer(uuid, integer, numeric) from public, anon, authenticated;
grant execute on function public.quiz_daily_start() to authenticated;
grant execute on function public.quiz_daily_answer(uuid, integer, numeric) to authenticated;

notify pgrst, 'reload schema';
commit;
