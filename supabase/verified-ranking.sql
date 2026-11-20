-- 기존 프로젝트: Supabase SQL Editor에서 이 파일 전체를 한 번 실행하세요.
-- 신규 프로젝트에도 그대로 실행할 수 있습니다. PostgreSQL 15 이상 / UTF8 필요.
-- 기존 scores는 삭제하지 않고 legacy_leaderboard로 보관합니다.
-- Authentication > Providers > Anonymous Sign-Ins를 켜야 오늘의 도전을 사용할 수 있습니다.
-- 공개 players.json의 정답 열람, 브라우저 계정 재발급까지 막는 부정행위 방지 장치는 아닙니다.

begin;

-- 이전 버전의 원본 기록은 보관하되 클라이언트 쓰기를 닫습니다.
create table if not exists public.scores (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  nickname text not null,
  score integer not null,
  created_at timestamptz not null default now(),
  constraint scores_nickname_length check (char_length(nickname) between 1 and 12),
  constraint scores_score_range check (score between 0 and 1000)
);
alter table public.scores enable row level security;
revoke all privileges on table public.scores from public, anon, authenticated;
-- 테이블 권한 회수만으로는 이전의 컬럼 단위 INSERT 권한이 회수되지 않습니다.
revoke insert (id, nickname, score, created_at), update (id, nickname, score, created_at),
  references (id, nickname, score, created_at)
  on table public.scores from public, anon, authenticated;
grant usage on schema public to anon, authenticated;
grant select on table public.scores to anon, authenticated;
drop policy if exists scores_anon_insert on public.scores;
drop policy if exists scores_anon_select on public.scores;
drop policy if exists scores_legacy_select on public.scores;
create policy scores_legacy_select on public.scores
  for select to anon, authenticated using (true);

create or replace view public.legacy_leaderboard with (security_invoker = true) as
select distinct on (nickname) id, nickname, score, created_at
from public.scores
order by nickname, score desc, created_at asc, id asc;
revoke all privileges on table public.legacy_leaderboard from public, anon, authenticated;
grant select on table public.legacy_leaderboard to anon, authenticated;
comment on view public.legacy_leaderboard is '이전 클라이언트 채점 기록의 보관용 랭킹. 새 검증 랭킹과 합산하지 않습니다.';

create schema if not exists quiz_private;
revoke all privileges on schema quiz_private from public, anon, authenticated;

create table if not exists quiz_private.quiz_questions (
  id integer primary key check (id between 1 and 82),
  payload jsonb not null check (jsonb_typeof(payload) = 'object')
);

-- players.json의 82개 원본 객체를 순서대로 적재합니다. 선수 값은 변경하지 않습니다.
-- 재실행은 기존 값을 덮어쓰지 않으며 원본과 다른 적재값이 있으면 전체를 롤백합니다.
do $seed$
declare
  v_seed jsonb := $quiz_players$[
{"name":"강민호","pos":"포수","from":"롯데","to":"잔류","year":2013,"term":"4년","amount":75,"guarantee":75,"option":0,"type":"b","stats":[[2011,0.289,19,66,0.846],[2012,0.273,19,66,0.823],[2013,0.235,11,57,0.742]],"source":"https://www.kukinews.com/article/view/kuk201311140211"},
{"name":"정근우","pos":"내야수","from":"SK","to":"한화","year":2013,"term":"4년","amount":70,"guarantee":63,"option":7,"type":"b","stats":[[2011,0.307,6,40,0.804],[2012,0.266,8,46,0.701],[2013,0.28,9,35,0.776]],"source":"https://www.twig24.com/news/baseball/2013/11/17/20131117800152"},
{"name":"이용규","pos":"외야수","from":"KIA","to":"한화","year":2013,"term":"4년","amount":67,"guarantee":60,"option":7,"type":"b","stats":[[2011,0.333,3,33,0.828],[2012,0.283,2,37,0.709],[2013,0.295,2,22,0.742]],"source":"https://www.twig24.com/news/baseball/2013/11/17/20131117800152"},
{"name":"이종욱","pos":"외야수","from":"두산","to":"NC","year":2013,"term":"4년","amount":50,"guarantee":48,"option":2,"type":"b","stats":[[2011,0.303,5,44,0.762],[2012,0.24,0,39,0.593],[2013,0.307,6,52,0.808]],"source":"https://newstomato.com/ReadNews.aspx?no=419147"},
{"name":"손시헌","pos":"내야수","from":"두산","to":"NC","year":2013,"term":"4년","amount":30,"guarantee":28,"option":2,"type":"b","stats":[[2011,0.282,4,28,0.74],[2012,0.246,5,31,0.655],[2013,0.252,1,26,0.661]],"source":"https://newstomato.com/ReadNews.aspx?no=419147"},
{"name":"최정","pos":"내야수","from":"SK","to":"잔류","year":2014,"term":"4년","amount":86,"guarantee":86,"option":0,"type":"b","stats":[[2012,0.3,26,84,0.923],[2013,0.316,28,83,0.98],[2014,0.305,14,76,0.903]],"source":"https://m.seoul.co.kr/news/2014/11/27/20141127800002"},
{"name":"장원준","pos":"투수","from":"롯데","to":"두산","year":2014,"term":"4년","amount":84,"guarantee":80,"option":4,"type":"p","stats":[[2010,12,6,0,0,4.43],[2011,15,6,0,0,3.14],[2014,10,9,0,0,4.59]],"source":"https://mydaily.co.kr/page/view/2016112814583502222"},
{"name":"윤성환","pos":"투수","from":"삼성","to":"잔류","year":2014,"term":"4년","amount":80,"guarantee":80,"option":0,"type":"p","stats":[[2012,9,6,0,0,2.84],[2013,13,8,0,0,3.27],[2014,12,7,0,0,4.39]],"source":"https://www.ajunews.com/view/20141127082735114"},
{"name":"안지만","pos":"투수","from":"삼성","to":"잔류","year":2014,"term":"4년","amount":65,"guarantee":65,"option":0,"type":"p","stats":[[2012,1,2,0,28,1.71],[2013,6,2,0,22,3.11],[2014,6,3,1,27,3.75]],"source":"https://osen.co.kr/article/G1112454831"},
{"name":"김강민","pos":"외야수","from":"SK","to":"잔류","year":2014,"term":"4년","amount":56,"guarantee":52,"option":4,"type":"b","stats":[[2012,0.272,5,31,0.676],[2013,0.301,10,55,0.836],[2014,0.302,16,82,0.863]],"source":"https://www.kyeonggi.com/article/201411270615471"},
{"name":"박용택","pos":"외야수","from":"LG","to":"잔류","year":2014,"term":"4년","amount":50,"guarantee":50,"option":0,"type":"b","stats":[[2012,0.305,11,76,0.813],[2013,0.328,7,67,0.828],[2014,0.343,9,73,0.891]],"source":"https://www.lg.co.kr/media/release/3780"},
{"name":"박석민","pos":"내야수","from":"삼성","to":"NC","year":2015,"term":"4년","amount":96,"guarantee":86,"option":10,"type":"b","stats":[[2013,0.318,18,76,0.94],[2014,0.315,27,72,1.02],[2015,0.321,26,116,0.992]],"source":"https://mydaily.co.kr/page/view/2016112814583502222"},
{"name":"정우람","pos":"투수","from":"SK","to":"한화","year":2015,"term":"4년","amount":84,"guarantee":84,"option":0,"type":"p","stats":[[2011,4,0,7,25,1.81],[2012,2,4,30,0,2.2],[2015,7,5,16,11,3.21]],"source":"https://mobile.busan.com/view/busan/view.php?code=20151130000283"},
{"name":"유한준","pos":"외야수","from":"넥센","to":"KT","year":2015,"term":"4년","amount":60,"guarantee":60,"option":0,"type":"b","stats":[[2013,0.272,7,40,0.744],[2014,0.316,20,91,0.925],[2015,0.362,23,116,1.009]],"source":"https://m.etnews.com/20151129000187"},
{"name":"손승락","pos":"투수","from":"넥센","to":"롯데","year":2015,"term":"4년","amount":60,"guarantee":60,"option":0,"type":"p","stats":[[2013,3,2,46,0,2.3],[2014,3,5,32,0,4.33],[2015,4,6,23,0,3.82]],"source":"https://www.segye.com/newsView/20151130002345"},
{"name":"이승엽","pos":"내야수","from":"삼성","to":"잔류","year":2015,"term":"2년","amount":36,"guarantee":36,"option":0,"type":"b","stats":[[2013,0.253,13,69,0.693],[2014,0.308,32,101,0.915],[2015,0.332,26,90,0.949]],"source":"https://nocutnews.co.kr/news/4510885"},
{"name":"정상호","pos":"포수","from":"SK","to":"LG","year":2015,"term":"4년","amount":32,"guarantee":30,"option":2,"type":"b","stats":[[2013,0.289,6,26,0.793],[2014,0.238,9,39,0.722],[2015,0.254,12,49,0.772]],"source":"https://www.lg.co.kr/media/release/4987"},
{"name":"이동현","pos":"투수","from":"LG","to":"잔류","year":2015,"term":"3년","amount":30,"guarantee":30,"option":0,"type":"p","stats":[[2013,6,3,1,25,3],[2014,5,1,2,23,2.73],[2015,5,5,4,11,4.4]],"source":"https://www.lg.co.kr/media/release/4988"},
{"name":"최형우","pos":"외야수","from":"삼성","to":"KIA","year":2016,"term":"4년","amount":100,"guarantee":100,"option":0,"type":"b","stats":[[2014,0.356,31,100,1.075],[2015,0.318,33,123,0.965],[2016,0.376,31,144,1.115]],"source":"https://osen.co.kr/article/G1110553185"},
{"name":"차우찬","pos":"투수","from":"삼성","to":"LG","year":2016,"term":"4년","amount":95,"guarantee":null,"option":0,"type":"p","stats":[[2014,3,4,0,21,5.6],[2015,13,7,0,1,4.79],[2016,12,6,0,0,4.73]],"source":"https://lg.co.kr/media/release/6532"},
{"name":"김광현","pos":"투수","from":"SK","to":"잔류","year":2016,"term":"4년","amount":85,"guarantee":85,"option":0,"type":"p","stats":[[2014,13,9,0,0,3.42],[2015,14,6,0,1,3.72],[2016,11,8,0,1,3.88]],"source":"https://osen.co.kr/article/G1111685688"},
{"name":"우규민","pos":"투수","from":"LG","to":"삼성","year":2016,"term":"4년","amount":65,"guarantee":65,"option":0,"type":"p","stats":[[2014,11,5,0,0,4.04],[2015,11,9,0,0,3.42],[2016,6,11,0,1,4.91]],"source":"https://osen.co.kr/article/G1110547790"},
{"name":"김재호","pos":"내야수","from":"두산","to":"잔류","year":2016,"term":"4년","amount":50,"guarantee":46,"option":4,"type":"b","stats":[[2014,0.252,3,54,0.674],[2015,0.307,3,50,0.788],[2016,0.31,7,78,0.829]],"source":"https://mydaily.co.kr/page/view/2016112814583502222"},
{"name":"나지완","pos":"외야수","from":"KIA","to":"잔류","year":2016,"term":"4년","amount":40,"guarantee":40,"option":0,"type":"b","stats":[[2014,0.312,19,79,0.914],[2015,0.253,7,31,0.753],[2016,0.308,25,90,1.022]],"source":"https://www.xportsnews.com/article/798369"},
{"name":"손아섭","pos":"외야수","from":"롯데","to":"잔류","year":2017,"term":"4년","amount":98,"guarantee":null,"option":0,"type":"b","stats":[[2015,0.317,13,54,0.878],[2016,0.323,16,81,0.886],[2017,0.335,20,80,0.934]],"source":"https://osen.co.kr/article/G1111704051"},
{"name":"강민호","pos":"포수","from":"롯데","to":"삼성","year":2017,"term":"4년","amount":80,"guarantee":80,"option":0,"type":"b","stats":[[2015,0.311,35,86,1.06],[2016,0.323,20,72,0.982],[2017,0.285,22,68,0.843]],"source":"https://kbmaeil.com/article/201711220207669"},
{"name":"민병헌","pos":"외야수","from":"두산","to":"롯데","year":2017,"term":"4년","amount":80,"guarantee":null,"option":0,"type":"b","stats":[[2015,0.303,12,75,0.799],[2016,0.325,16,87,0.891],[2017,0.304,14,71,0.834]],"source":"https://osen.co.kr/article/G1110785325"},
{"name":"양의지","pos":"포수","from":"두산","to":"NC","year":2018,"term":"4년","amount":125,"guarantee":125,"option":0,"type":"b","stats":[[2016,0.319,22,66,0.973],[2017,0.277,14,67,0.814],[2018,0.358,23,77,1.012]],"source":"https://www.ajunews.com/view/20181211102211188"},
{"name":"최정","pos":"내야수","from":"SK","to":"잔류","year":2018,"term":"6년","amount":106,"guarantee":100,"option":6,"type":"b","stats":[[2016,0.288,40,106,0.983],[2017,0.316,46,113,1.111],[2018,0.244,35,74,0.915]],"source":"https://www.kyeonggi.com/article/201812051029123"},
{"name":"이재원","pos":"포수","from":"SK","to":"잔류","year":2018,"term":"4년","amount":69,"guarantee":69,"option":0,"type":"b","stats":[[2016,0.29,15,64,0.8],[2017,0.242,9,42,0.668],[2018,0.329,17,57,0.919]],"source":"https://www.kyeonggi.com/article/201812051029123"},
{"name":"정우람","pos":"투수","from":"한화","to":"잔류","year":2019,"term":"4년","amount":39,"guarantee":39,"option":0,"type":"p","stats":[[2017,6,4,26,0,2.75],[2018,5,3,35,0,3.4],[2019,4,3,26,0,1.54]],"source":"https://osen.co.kr/article/G1111268010"},
{"name":"오지환","pos":"내야수","from":"LG","to":"잔류","year":2019,"term":"4년","amount":40,"guarantee":40,"option":0,"type":"b","stats":[[2017,0.272,8,39,0.769],[2018,0.278,11,71,0.75],[2019,0.252,9,53,0.717]],"source":"https://sports.khan.co.kr/article/201912201119003"},
{"name":"박석민","pos":"내야수","from":"NC","to":"잔류","year":2019,"term":"2+1년","amount":34,"guarantee":16,"option":18,"type":"b","stats":[[2017,0.245,14,56,0.792],[2018,0.255,16,55,0.816],[2019,0.267,19,74,0.871]],"source":"https://www.dailian.co.kr/news/view/859448/"},
{"name":"전준우","pos":"외야수","from":"롯데","to":"잔류","year":2019,"term":"4년","amount":34,"guarantee":32,"option":2,"type":"b","stats":[[2017,0.321,18,69,0.873],[2018,0.342,33,90,0.992],[2019,0.301,22,83,0.84]],"source":"https://kpinews.kr/newsView/179545793499002"},
{"name":"김선빈","pos":"내야수","from":"KIA","to":"잔류","year":2019,"term":"4년","amount":40,"guarantee":34,"option":6,"type":"b","stats":[[2017,0.37,5,64,0.897],[2018,0.295,4,49,0.747],[2019,0.292,3,40,0.731]],"source":"https://www.asiae.co.kr/en/article/2020011408423702788"},
{"name":"허경민","pos":"내야수","from":"두산","to":"잔류","year":2020,"term":"4+3년","amount":85,"guarantee":65,"option":20,"type":"b","stats":[[2018,0.324,10,79,0.835],[2019,0.288,4,60,0.721],[2020,0.332,7,58,0.824]],"source":"https://sports.khan.co.kr/article/202012171809003"},
{"name":"최주환","pos":"내야수","from":"두산","to":"SK","year":2020,"term":"4년","amount":42,"guarantee":38,"option":4,"type":"b","stats":[[2018,0.333,26,108,0.979],[2019,0.277,4,47,0.697],[2020,0.306,16,88,0.839]],"source":"https://sports.khan.co.kr/article/202012111133003"},
{"name":"오재일","pos":"내야수","from":"두산","to":"삼성","year":2020,"term":"4년","amount":50,"guarantee":46,"option":4,"type":"b","stats":[[2018,0.279,27,80,0.912],[2019,0.293,21,102,0.864],[2020,0.312,16,89,0.872]],"source":"https://sports.khan.co.kr/article/202012141646003"},
{"name":"최형우","pos":"외야수","from":"KIA","to":"잔류","year":2020,"term":"3년","amount":47,"guarantee":40,"option":7,"type":"b","stats":[[2018,0.339,25,103,0.963],[2019,0.3,17,86,0.898],[2020,0.354,28,115,1.023]],"source":"https://osen.co.kr/article/G1111493060"},
{"name":"정수빈","pos":"외야수","from":"두산","to":"잔류","year":2020,"term":"6년","amount":56,"guarantee":52,"option":4,"type":"b","stats":[[2018,0.367,2,23,0.898],[2019,0.265,0,41,0.685],[2020,0.298,5,59,0.764]],"source":"https://sports.khan.co.kr/article/202012171809003"},
{"name":"최재훈","pos":"포수","from":"한화","to":"잔류","year":2021,"term":"5년","amount":54,"guarantee":49,"option":5,"type":"b","stats":[[2019,0.29,3,31,0.76],[2020,0.301,3,36,0.766],[2021,0.275,7,44,0.792]],"source":"https://osen.co.kr/article/G1111702422"},
{"name":"박해민","pos":"외야수","from":"삼성","to":"LG","year":2021,"term":"4년","amount":60,"guarantee":56,"option":4,"type":"b","stats":[[2019,0.239,5,44,0.646],[2020,0.29,11,55,0.76],[2021,0.291,5,54,0.76]],"source":"https://www.lg.co.kr/media/release/24229"},
{"name":"박건우","pos":"외야수","from":"두산","to":"NC","year":2021,"term":"6년","amount":100,"guarantee":94,"option":6,"type":"b","stats":[[2019,0.319,10,64,0.862],[2020,0.304,14,70,0.841],[2021,0.325,6,63,0.841]],"source":"https://isplus.com/article/view/isp202112140117"},
{"name":"백정현","pos":"투수","from":"삼성","to":"잔류","year":2021,"term":"4년","amount":38,"guarantee":34,"option":4,"type":"p","stats":[[2019,8,10,0,0,4.24],[2020,4,4,0,0,5.19],[2021,14,5,0,0,2.63]],"source":"https://www.mksports.co.kr/news/sports/10138636"},
{"name":"김재환","pos":"외야수","from":"두산","to":"잔류","year":2021,"term":"4년","amount":115,"guarantee":110,"option":5,"type":"b","stats":[[2019,0.283,15,91,0.796],[2020,0.266,30,113,0.867],[2021,0.274,27,102,0.883]],"source":"https://news.sbs.co.kr/news/endPage.do?news_id=N1006572834"},
{"name":"김현수","pos":"외야수","from":"LG","to":"잔류","year":2021,"term":"4+2년","amount":115,"guarantee":90,"option":25,"type":"b","stats":[[2019,0.304,11,82,0.807],[2020,0.331,22,119,0.92],[2021,0.285,17,96,0.811]],"source":"https://www.fnnews.com/news/202112171633552461"},
{"name":"장성우","pos":"포수","from":"KT","to":"잔류","year":2021,"term":"4년","amount":42,"guarantee":38,"option":4,"type":"b","stats":[[2019,0.262,7,41,0.664],[2020,0.278,13,79,0.75],[2021,0.231,14,63,0.711]],"source":"https://v.daum.net/v/20260118163124547"},
{"name":"나성범","pos":"외야수","from":"NC","to":"KIA","year":2021,"term":"6년","amount":150,"guarantee":120,"option":30,"type":"b","stats":[[2019,0.366,4,14,1.088],[2020,0.324,34,112,0.986],[2021,0.281,33,101,0.844]],"source":"https://www.munhwa.com/article/11276491"},
{"name":"손아섭","pos":"외야수","from":"롯데","to":"NC","year":2021,"term":"4년","amount":64,"guarantee":56,"option":8,"type":"b","stats":[[2019,0.295,10,63,0.76],[2020,0.352,11,85,0.908],[2021,0.319,3,58,0.787]],"source":"https://www.inews24.com/view/1435789"},
{"name":"강민호","pos":"포수","from":"삼성","to":"잔류","year":2021,"term":"4년","amount":36,"guarantee":32,"option":4,"type":"b","stats":[[2019,0.234,13,45,0.72],[2020,0.287,19,61,0.836],[2021,0.291,18,67,0.839]],"source":"https://www.mksports.co.kr/news/sports/10149706"},
{"name":"황재균","pos":"내야수","from":"KT","to":"잔류","year":2021,"term":"4년","amount":60,"guarantee":54,"option":6,"type":"b","stats":[[2019,0.283,20,67,0.824],[2020,0.312,21,97,0.882],[2021,0.291,10,56,0.76]],"source":"https://www.spotvnews.co.kr/news/articleView.html?idxno=461371"},
{"name":"박병호","pos":"내야수","from":"키움","to":"KT","year":2021,"term":"3년","amount":30,"guarantee":27,"option":3,"type":"b","stats":[[2019,0.28,33,98,0.958],[2020,0.223,21,66,0.802],[2021,0.227,20,76,0.753]],"source":"https://www.mksports.co.kr/news/sports/10155257"},
{"name":"양의지","pos":"포수","from":"NC","to":"두산","year":2022,"term":"4+2년","amount":152,"guarantee":110,"option":42,"type":"b","stats":[[2020,0.328,33,124,1.003],[2021,0.325,30,111,0.995],[2022,0.283,20,94,0.86]],"source":"https://www.segye.com/newsView/20221122512665"},
{"name":"박민우","pos":"내야수","from":"NC","to":"잔류","year":2022,"term":"5+3년","amount":140,"guarantee":80,"option":60,"type":"b","stats":[[2020,0.345,8,63,0.877],[2021,0.261,1,18,0.699],[2022,0.267,4,38,0.71]],"source":"https://mobile.newsis.com/view/NISX20221123_0002097899"},
{"name":"채은성","pos":"내야수","from":"LG","to":"한화","year":2022,"term":"6년","amount":90,"guarantee":80,"option":10,"type":"b","stats":[[2020,0.293,15,88,0.803],[2021,0.276,16,82,0.811],[2022,0.296,12,83,0.791]],"source":"https://osen.co.kr/article/G1111993864"},
{"name":"유강남","pos":"포수","from":"LG","to":"롯데","year":2022,"term":"4년","amount":80,"guarantee":74,"option":6,"type":"b","stats":[[2020,0.261,16,74,0.745],[2021,0.252,11,60,0.692],[2022,0.255,8,47,0.677]],"source":"https://isplus.com/article/view/isp202211210149"},
{"name":"박동원","pos":"포수","from":"KIA","to":"LG","year":2022,"term":"4년","amount":65,"guarantee":65,"option":0,"type":"b","stats":[[2020,0.25,12,50,0.764],[2021,0.249,22,83,0.802],[2022,0.242,18,57,0.77]],"source":"https://lg.co.kr/media/release/25587"},
{"name":"노진혁","pos":"내야수","from":"NC","to":"롯데","year":2022,"term":"4년","amount":50,"guarantee":46,"option":4,"type":"b","stats":[[2020,0.274,20,82,0.836],[2021,0.288,8,58,0.801],[2022,0.28,15,75,0.808]],"source":"https://isplus.com/article/view/isp202211230083"},
{"name":"박세혁","pos":"포수","from":"두산","to":"NC","year":2022,"term":"4년","amount":46,"guarantee":42,"option":4,"type":"b","stats":[[2020,0.269,4,51,0.712],[2021,0.219,0,30,0.566],[2022,0.248,3,41,0.636]],"source":"https://isplus.com/article/view/isp202211240090"},
{"name":"한현희","pos":"투수","from":"키움","to":"롯데","year":2022,"term":"3+1년","amount":40,"guarantee":18,"option":22,"type":"p","stats":[[2020,7,9,0,0,4.98],[2021,6,2,0,1,3.89],[2022,6,4,0,0,4.75]],"source":"https://osen.co.kr/article/G1112243022"},
{"name":"양석환","pos":"내야수","from":"두산","to":"잔류","year":2023,"term":"4+2년","amount":78,"guarantee":59,"option":19,"type":"b","stats":[[2021,0.273,28,96,0.827],[2022,0.244,20,51,0.741],[2023,0.281,21,89,0.787]],"source":"https://osen.co.kr/article/G1112250525"},
{"name":"안치홍","pos":"내야수","from":"롯데","to":"한화","year":2023,"term":"4+2년","amount":72,"guarantee":47,"option":25,"type":"b","stats":[[2021,0.306,10,82,0.837],[2022,0.284,14,58,0.79],[2023,0.292,8,63,0.774]],"source":"https://osen.co.kr/article/G1112227099"},
{"name":"김재윤","pos":"투수","from":"KT","to":"삼성","year":2023,"term":"4년","amount":58,"guarantee":48,"option":10,"type":"p","stats":[[2021,4,3,32,0,2.42],[2022,9,7,33,0,3.26],[2023,5,5,32,0,2.6]],"source":"https://osen.co.kr/article/G1112250525"},
{"name":"임찬규","pos":"투수","from":"LG","to":"잔류","year":2023,"term":"4년","amount":50,"guarantee":26,"option":24,"type":"p","stats":[[2021,1,8,0,0,3.87],[2022,6,11,0,0,5.04],[2023,14,3,0,1,3.42]],"source":"https://osen.co.kr/article/G1112250525"},
{"name":"전준우","pos":"외야수","from":"롯데","to":"잔류","year":2023,"term":"4년","amount":47,"guarantee":40,"option":7,"type":"b","stats":[[2021,0.348,7,92,0.874],[2022,0.304,11,68,0.795],[2023,0.312,17,77,0.852]],"source":"https://osen.co.kr/article/G1112250525"},
{"name":"함덕주","pos":"투수","from":"LG","to":"잔류","year":2023,"term":"4년","amount":38,"guarantee":20,"option":18,"type":"p","stats":[[2021,1,2,0,1,4.29],[2022,0,0,0,0,2.13],[2023,4,0,4,16,1.62]],"source":"https://osen.co.kr/article/G1112250525"},
{"name":"김선빈","pos":"내야수","from":"KIA","to":"잔류","year":2023,"term":"3년","amount":30,"guarantee":24,"option":6,"type":"b","stats":[[2021,0.307,5,67,0.776],[2022,0.287,3,61,0.723],[2023,0.32,0,48,0.739]],"source":"https://osen.co.kr/article/G1112250525"},
{"name":"최정","pos":"내야수","from":"SSG","to":"잔류","year":2024,"term":"4년","amount":110,"guarantee":110,"option":0,"type":"b","stats":[[2022,0.266,26,87,0.891],[2023,0.297,29,87,0.936],[2024,0.291,37,107,0.978]],"source":"https://osen.co.kr/article/G1112451670"},
{"name":"엄상백","pos":"투수","from":"KT","to":"한화","year":2024,"term":"4년","amount":78,"guarantee":66.5,"option":11.5,"type":"p","stats":[[2022,11,2,0,0,2.95],[2023,7,6,0,0,3.63],[2024,13,10,0,0,4.88]],"source":"https://osen.co.kr/article/G1112453148"},
{"name":"최원태","pos":"투수","from":"LG","to":"삼성","year":2024,"term":"4년","amount":70,"guarantee":58,"option":12,"type":"p","stats":[[2022,7,5,0,0,3.75],[2023,9,7,0,0,4.3],[2024,9,7,0,0,4.26]],"source":"https://v.daum.net/v/20241206090608603"},
{"name":"김원중","pos":"투수","from":"롯데","to":"잔류","year":2024,"term":"4년","amount":54,"guarantee":44,"option":10,"type":"p","stats":[[2022,2,3,17,2,3.98],[2023,5,6,30,0,2.97],[2024,3,6,25,0,3.55]],"source":"https://v.daum.net/v/20241110184024069"},
{"name":"장현식","pos":"투수","from":"KIA","to":"LG","year":2024,"term":"4년","amount":52,"guarantee":52,"option":0,"type":"p","stats":[[2022,2,3,1,19,3.12],[2023,2,2,3,5,4.06],[2024,5,4,0,16,3.94]],"source":"http://www.osen.co.kr/article/G1112454828"},
{"name":"심우준","pos":"내야수","from":"KT","to":"한화","year":2024,"term":"4년","amount":50,"guarantee":42,"option":8,"type":"b","stats":[[2021,0.268,6,48,0.694],[2022,0.24,4,34,0.618],[2024,0.266,3,28,0.68]],"source":"https://www.osen.co.kr/article/G1112452428"},
{"name":"허경민","pos":"내야수","from":"두산","to":"KT","year":2024,"term":"4년","amount":40,"guarantee":34,"option":6,"type":"b","stats":[[2022,0.289,8,60,0.758],[2023,0.268,7,48,0.703],[2024,0.309,7,61,0.811]],"source":"https://osen.co.kr/article/G1112453232"},
{"name":"강백호","pos":"내야수","from":"KT","to":"한화","year":2025,"term":"4년","amount":100,"guarantee":80,"option":20,"type":"b","stats":[[2023,0.265,8,39,0.763],[2024,0.289,26,96,0.84],[2025,0.265,15,61,0.825]],"source":"https://mobile.newsis.com/view/NISX20251120_0003410995"},
{"name":"박찬호","pos":"내야수","from":"KIA","to":"두산","year":2025,"term":"4년","amount":80,"guarantee":78,"option":2,"type":"b","stats":[[2023,0.301,3,52,0.734],[2024,0.307,5,61,0.749],[2025,0.287,5,42,0.722]],"source":"https://mobile.newsis.com/view/NISX20251118_0003407235"},
{"name":"박해민","pos":"외야수","from":"LG","to":"잔류","year":2025,"term":"4년","amount":65,"guarantee":60,"option":5,"type":"b","stats":[[2023,0.285,6,59,0.707],[2024,0.263,6,56,0.695],[2025,0.276,3,43,0.725]],"source":"https://v.daum.net/v/20251121173421921"},
{"name":"이영하","pos":"투수","from":"두산","to":"잔류","year":2025,"term":"4년","amount":52,"guarantee":46,"option":6,"type":"p","stats":[[2023,5,3,0,4,5.49],[2024,5,4,2,5,3.99],[2025,4,4,0,14,4.05]],"source":"https://www.newdaily.co.kr/site/data/html/2025/11/27/2025112700232.html"},
{"name":"김현수","pos":"외야수","from":"LG","to":"KT","year":2025,"term":"3년","amount":50,"guarantee":50,"option":0,"type":"b","stats":[[2023,0.293,6,88,0.747],[2024,0.294,8,69,0.775],[2025,0.298,12,90,0.806]],"source":"https://osen.co.kr/article/G1112702534"},
{"name":"최원준","pos":"외야수","from":"NC","to":"KT","year":2025,"term":"4년","amount":48,"guarantee":42,"option":6,"type":"b","stats":[[2023,0.255,1,23,0.672],[2024,0.292,9,56,0.791],[2025,0.242,6,44,0.621]],"source":"https://osen.co.kr/article/G1112702530"},
{"name":"양현종","pos":"투수","from":"KIA","to":"잔류","year":2025,"term":"2+1년","amount":45,"guarantee":null,"option":0,"type":"p","stats":[[2023,9,11,0,0,3.58],[2024,11,5,0,0,4.1],[2025,7,9,0,0,5.06]],"source":"https://v.daum.net/v/9GSbMQV7Ct"},
{"name":"최원준","pos":"투수","from":"두산","to":"잔류","year":2025,"term":"4년","amount":38,"guarantee":34,"option":4,"type":"p","stats":[[2023,3,10,0,0,4.93],[2024,6,7,0,0,6.46],[2025,4,7,0,9,4.71]],"source":"https://isplus.com/article/view/isp202511280043"}
]
$quiz_players$::jsonb;
begin
  if pg_catalog.jsonb_array_length(v_seed) <> 82 then
    raise exception 'QUIZ_SEED_COUNT_MISMATCH';
  end if;
  insert into quiz_private.quiz_questions (id, payload)
  select ordinality::integer, value
  from pg_catalog.jsonb_array_elements(v_seed) with ordinality
  on conflict (id) do nothing;
  if (select pg_catalog.count(*) from quiz_private.quiz_questions) <> 82
     or exists (
       select 1
       from pg_catalog.jsonb_array_elements(v_seed) with ordinality seed(value, ordinality)
       join quiz_private.quiz_questions q on q.id = seed.ordinality
       where q.payload is distinct from seed.value
     ) then
    raise exception 'QUIZ_SEED_DATA_MISMATCH';
  end if;
end
$seed$;

create table if not exists public.quiz_profiles (
  user_id uuid primary key,
  nickname text not null check (char_length(nickname) between 1 and 12),
  nickname_key text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists quiz_private.quiz_attempts (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  user_id uuid not null,
  challenge_date date not null,
  deck_ids integer[] not null check (cardinality(deck_ids) = 10),
  next_index integer not null default 0 check (next_index between 0 and 10),
  total integer not null default 0 check (total between 0 and 1000),
  answers jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  published_at timestamptz,
  constraint quiz_attempts_user_day_unique unique (user_id, challenge_date),
  constraint quiz_attempts_answers_length check (
    jsonb_typeof(answers) = 'array' and jsonb_array_length(answers) = next_index
  )
);

create table if not exists public.quiz_verified_scores (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  attempt_id uuid not null unique references quiz_private.quiz_attempts(id),
  user_id uuid not null references public.quiz_profiles(user_id),
  challenge_date date not null,
  score integer not null check (score between 0 and 1000),
  created_at timestamptz not null default now(),
  constraint quiz_verified_scores_user_day_unique unique (user_id, challenge_date)
);
create index if not exists quiz_verified_scores_best_idx
  on public.quiz_verified_scores (user_id, score desc, created_at asc, id asc);
create index if not exists quiz_verified_scores_day_idx
  on public.quiz_verified_scores (challenge_date, user_id, score desc, created_at asc, id asc);

create table if not exists quiz_private.quiz_rpc_limits (
  user_id uuid primary key,
  window_start timestamptz not null,
  calls integer not null check (calls > 0)
);

-- 공개 랭킹에 필요한 컬럼만 SELECT 가능. 정답/시도 상태/속도 제한은 비공개입니다.
alter table public.quiz_profiles enable row level security;
alter table public.quiz_verified_scores enable row level security;
alter table quiz_private.quiz_questions enable row level security;
alter table quiz_private.quiz_attempts enable row level security;
alter table quiz_private.quiz_rpc_limits enable row level security;
revoke all privileges on all tables in schema quiz_private from public, anon, authenticated;
revoke all privileges on table public.quiz_profiles, public.quiz_verified_scores from public, anon, authenticated;
revoke insert (user_id, nickname, nickname_key, created_at),
  update (user_id, nickname, nickname_key, created_at),
  references (user_id, nickname, nickname_key, created_at)
  on table public.quiz_profiles from public, anon, authenticated;
revoke insert (id, attempt_id, user_id, challenge_date, score, created_at),
  update (id, attempt_id, user_id, challenge_date, score, created_at),
  references (id, attempt_id, user_id, challenge_date, score, created_at)
  on table public.quiz_verified_scores from public, anon, authenticated;
grant select (user_id, nickname) on table public.quiz_profiles to anon, authenticated;
grant select (id, user_id, challenge_date, score, created_at)
  on table public.quiz_verified_scores to anon, authenticated;
drop policy if exists quiz_profiles_public_select on public.quiz_profiles;
create policy quiz_profiles_public_select on public.quiz_profiles
  for select to anon, authenticated using (true);
drop policy if exists quiz_verified_scores_public_select on public.quiz_verified_scores;
create policy quiz_verified_scores_public_select on public.quiz_verified_scores
  for select to anon, authenticated using (true);

-- uid ごとの成功 RPC を 60 秒窓で 90 回までに制限します。
-- PostgreSQL の例外時は取引全体が戻るため、拒否された不正リクエスト自体は加算されません。
-- 匿名アカウントの作り直しを防ぐ IP 単位の制限ではありません。
create or replace function quiz_private.touch_limit(p_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $fn$
declare
  v_now timestamptz := pg_catalog.clock_timestamp();
  v_calls integer;
begin
  insert into quiz_private.quiz_rpc_limits as limits (user_id, window_start, calls)
  values (p_user_id, v_now, 1)
  on conflict (user_id) do update set
    window_start = case when limits.window_start <= v_now - interval '60 seconds'
      then v_now else limits.window_start end,
    calls = case when limits.window_start <= v_now - interval '60 seconds'
      then 1 else limits.calls + 1 end
  returning calls into v_calls;
  if v_calls > 90 then
    raise exception using errcode = 'P0001', message = 'QUIZ_RATE_LIMITED';
  end if;
end
$fn$;

create or replace function quiz_private.attempt_state(p_attempt_id uuid, p_user_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $fn$
  select pg_catalog.jsonb_build_object(
    'attempt_id', a.id,
    'challenge_date', pg_catalog.to_char(a.challenge_date, 'YYYY-MM-DD'),
    'next_index', a.next_index,
    'total', a.total,
    'completed', a.next_index = 10,
    'published', a.published_at is not null,
    'nickname', p.nickname,
    'user_id', a.user_id,
    'deck', (
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object('question_id', q.id)
          || (q.payload - array['amount', 'guarantee', 'option', 'source']::text[])
        order by d.ordinality
      )
      from pg_catalog.unnest(a.deck_ids) with ordinality d(question_id, ordinality)
      join quiz_private.quiz_questions q on q.id = d.question_id
    ),
    'answers', a.answers
  )
  from quiz_private.quiz_attempts a
  left join public.quiz_profiles p on p.user_id = a.user_id
  where a.id = p_attempt_id and a.user_id = p_user_id;
$fn$;

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
  if v_attempt_id is not null then
    return quiz_private.attempt_state(v_attempt_id, v_user_id);
  end if;

  -- 全員に同じ韓国日付の 10 問。name+pos で同一選手の複数契約を除外します。
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

  -- 応答が失われた同一入力は日付変更後・完了後も回復できます。
  -- 既存の解答は変更できず、異なる guess での再採点は拒否します。
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
  v_points := greatest(0, pg_catalog.round(100 - pg_catalog.abs(p_guess - v_answer) / v_answer * 100))::integer;
  update quiz_private.quiz_attempts set
    answers = answers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'question_id', v_attempt.deck_ids[p_question_index + 1],
      'guess', p_guess, 'points', v_points, 'player', v_player
    )),
    next_index = next_index + 1,
    total = total + v_points,
    completed_at = case when next_index = 9 then pg_catalog.now() else completed_at end
  where id = v_attempt.id;
  return quiz_private.attempt_state(v_attempt.id, v_user_id);
end
$fn$;

create or replace function public.quiz_publish_score(p_attempt_id uuid, p_nickname text)
returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare
  v_user_id uuid := auth.uid();
  v_today date := (pg_catalog.now() at time zone 'Asia/Seoul')::date;
  v_attempt quiz_private.quiz_attempts%rowtype;
  v_profile public.quiz_profiles%rowtype;
  v_nickname text;
  v_key text;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'QUIZ_AUTH_REQUIRED';
  end if;
  perform quiz_private.touch_limit(v_user_id);
  -- NFC と両端空白除去。不可視の制御文字・ゼロ幅・方向制御を拒否します。
  v_nickname := pg_catalog.normalize(pg_catalog.btrim(p_nickname), 'NFC');
  if v_nickname is null or pg_catalog.char_length(v_nickname) not between 1 and 12
     or v_nickname ~ '[[:cntrl:]]'
     or v_nickname ~ U&'[\00AD\034F\061C\115F\1160\17B4\17B5\180B-\180F\200B-\200F\202A-\202E\2060-\206F\2800\3164\FE00-\FE0F\FEFF\FFA0]'
  then
    raise exception using errcode = '22023', message = 'QUIZ_INVALID_NICKNAME';
  end if;
  -- PG15+ の lower 規則による大文字小文字無視。Unicode full casefold ではありません。
  v_key := pg_catalog.lower(v_nickname);
  select * into v_attempt from quiz_private.quiz_attempts
    where id = p_attempt_id and user_id = v_user_id for update;
  if not found then
    raise exception using errcode = '42501', message = 'QUIZ_ATTEMPT_NOT_FOUND';
  end if;
  select * into v_profile from public.quiz_profiles where user_id = v_user_id;
  if found and v_profile.nickname_key <> v_key then
    raise exception using errcode = '22023', message = 'QUIZ_NICKNAME_FIXED';
  end if;
  if v_attempt.published_at is not null then
    return pg_catalog.jsonb_build_object('score', v_attempt.total,
      'nickname', v_profile.nickname, 'published', true, 'user_id', v_user_id);
  end if;
  if v_attempt.challenge_date <> v_today then
    raise exception using errcode = '22023', message = 'QUIZ_ATTEMPT_EXPIRED';
  end if;
  if v_attempt.next_index <> 10 or v_attempt.completed_at is null then
    raise exception using errcode = '22023', message = 'QUIZ_NOT_COMPLETED';
  end if;
  if v_profile.user_id is null then
    begin
      insert into public.quiz_profiles (user_id, nickname, nickname_key)
      values (v_user_id, v_nickname, v_key);
    exception when unique_violation then
      raise exception using errcode = '23505', message = 'QUIZ_NICKNAME_TAKEN';
    end;
    select * into v_profile from public.quiz_profiles where user_id = v_user_id;
  end if;
  insert into public.quiz_verified_scores (attempt_id, user_id, challenge_date, score)
  values (v_attempt.id, v_user_id, v_attempt.challenge_date, v_attempt.total);
  update quiz_private.quiz_attempts set published_at = pg_catalog.now() where id = v_attempt.id;
  return pg_catalog.jsonb_build_object('score', v_attempt.total,
    'nickname', v_profile.nickname, 'published', true, 'user_id', v_user_id);
end
$fn$;

-- 補助関数と非公開スキーマは RPC からだけ使用可能です。
revoke all privileges on all functions in schema quiz_private from public, anon, authenticated;
revoke all privileges on function public.quiz_daily_start() from public, anon, authenticated;
revoke all privileges on function public.quiz_daily_answer(uuid, integer, numeric) from public, anon, authenticated;
revoke all privileges on function public.quiz_publish_score(uuid, text) from public, anon, authenticated;
grant execute on function public.quiz_daily_start() to authenticated;
grant execute on function public.quiz_daily_answer(uuid, integer, numeric) to authenticated;
grant execute on function public.quiz_publish_score(uuid, text) to authenticated;

-- 最初の4列は旧ビューと同じ型・順番で維持し、user_idだけ末尾に追加します。
-- 基底テーブルの公開SELECT列/RLSを使い、definerビューで秘密データを迂回公開しません。
create or replace view public.leaderboard with (security_invoker = true) as
select distinct on (s.user_id) s.id, p.nickname, s.score, s.created_at, s.user_id
from public.quiz_verified_scores s
join public.quiz_profiles p on p.user_id = s.user_id
order by s.user_id, s.score desc, s.created_at asc, s.id asc;
create or replace view public.daily_leaderboard with (security_invoker = true) as
select distinct on (s.user_id) s.id, p.nickname, s.score, s.created_at, s.user_id
from public.quiz_verified_scores s
join public.quiz_profiles p on p.user_id = s.user_id
where s.challenge_date = (pg_catalog.now() at time zone 'Asia/Seoul')::date
order by s.user_id, s.score desc, s.created_at asc, s.id asc;
revoke all privileges on table public.leaderboard, public.daily_leaderboard from public, anon, authenticated;
grant select on table public.leaderboard, public.daily_leaderboard to anon, authenticated;
comment on view public.leaderboard is 'サーバー採点・ブラウザアカウント別の全期間最高点。旧記録はlegacy_leaderboardに保管。';
comment on view public.daily_leaderboard is '韓国の今日の共通10問。各ブラウザアカウントの最初の挑戦のみ。TOP10はscore DESC, created_at ASC, id ASC。';

notify pgrst, 'reload schema';
commit;
