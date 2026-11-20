# FA 몸값 퀴즈

빌드 없이 실행하는 정적 웹 게임입니다. 문제는 `players.json`을 그대로 읽고, 랭킹만 Supabase에 저장합니다.

공개 주소: [FA 몸값 퀴즈](https://kbo-fa-quiz.vercel.app/). 개인 GitHub 저장소의 `main` 변경 사항이 Vercel로 자동 배포됩니다.

## 1. Supabase 프로젝트 만들기

1. [Supabase 대시보드](https://supabase.com/dashboard)에 로그인합니다.
2. 새 프로젝트를 만들고 조직, 프로젝트 이름, 데이터베이스 비밀번호, 리전을 지정합니다. 비밀번호는 안전한 곳에 보관하고 웹 파일에는 넣지 않습니다.
3. 프로젝트 준비가 끝나면 왼쪽 **SQL Editor**에서 새 쿼리를 엽니다.
4. 이 폴더의 `supabase/schema.sql` 전체를 붙여 넣고 실행합니다.
5. **Table Editor**에서 `scores` 테이블을 확인합니다. SQL은 전체 랭킹 `leaderboard`와 일일 랭킹 `daily_leaderboard` 뷰도 만듭니다.

기존 프로젝트에 일일 랭킹만 추가하려면 `supabase/daily-ranking.sql`을 실행합니다. 기존 점수는 유지합니다.

스키마는 익명 방문자에게 조회와 점수 등록만 허용하고, 수정·삭제는 허용하지 않습니다. 뷰도 원본 테이블의 RLS를 적용합니다. [Supabase RLS 문서](https://supabase.com/docs/guides/database/postgres/row-level-security)

## 2. 공개 접속 키 입력하기

1. 프로젝트의 **Connect** 창에서 Project URL을 복사합니다.
2. **Settings → API Keys**에서 브라우저용 공개 키를 복사합니다. 요청한 기존 방식은 **Legacy API Keys**의 `anon` 키입니다. 새 프로젝트에서는 `sb_publishable_...` 형식의 publishable 키를 사용해도 됩니다.
3. `index.html` 상단의 두 상수에 값을 넣고 저장합니다.

```js
const SUPABASE_URL = 'https://프로젝트식별자.supabase.co';
const SUPABASE_ANON_KEY = '복사한_anon_또는_publishable_키';
```

변수 이름은 `SUPABASE_ANON_KEY` 그대로 사용합니다. Supabase는 기존 `anon` 키를 2026년 말까지 폐기 예정으로 안내하므로 신규 설정에는 publishable 키를 권장합니다. 두 공개 키는 로그인하지 않은 방문자에게 동일한 `anon` 역할과 RLS를 적용합니다. **`service_role` 키, `sb_secret_...` 키, 데이터베이스 비밀번호는 HTML이나 GitHub에 넣지 마세요.** [API 키 안내](https://supabase.com/docs/guides/getting-started/api-keys), [새 키로 전환하기](https://supabase.com/docs/guides/getting-started/migrating-to-new-api-keys)

## 3. 로컬에서 확인하기

터미널에서 실행합니다.

```bash
cd /게임을_저장한_경로/kbo-fa-quiz
python3 -m http.server 8000 --bind 127.0.0.1
```

브라우저에서 [로컬 게임 열기](http://127.0.0.1:8000/)로 접속합니다. 종료는 터미널에서 `Ctrl+C`입니다. `index.html`을 더블클릭해 `file://`로 열면 브라우저가 `fetch('./players.json')`를 차단할 수 있으므로 HTTP 서버를 사용해야 합니다. 폰트와 Supabase CDN, 온라인 랭킹을 사용하려면 인터넷 연결도 필요합니다.

다음 동작을 확인해 보세요.

- 대문에 출제 풀 82명, 시작 버튼, 랭킹이 표시됩니다.
- 한 판에 서로 다른 선수 10명이 나오고, 공개 버튼과 Enter 모두 답을 제출합니다. 같은 선수의 다른 연도 FA 계약은 한 판에서 중복 출제하지 않으며, 동명이인 최원준은 포지션으로 구분합니다.
- 타율·OPS는 `.356`, 평균자책점은 `3.50`처럼 표시됩니다. 잔류 선수는 `두산 잔류` 형식으로 표시됩니다.
- 정답 공개 후 총액·보장·옵션, 내 답, 판정, 점수, 계약 기사 링크를 볼 수 있습니다.
- 10문제를 마치면 총점과 문제별 요약이 나타납니다. 닉네임을 등록한 뒤 다시 플레이하면 같은 닉네임이 미리 채워집니다.
- 결과 화면의 **홈으로**는 대문으로 이동하고, **랭킹 보기**는 현재 화면 위에 TOP 10 모달을 엽니다. 모달은 닫기 버튼, 바깥 영역 클릭, Esc로 닫을 수 있습니다.
- 동일 닉네임으로 다른 점수를 등록해도 TOP 10에는 그 닉네임의 최고점 한 건만 표시됩니다.
- 대문과 랭킹 모달에서 **일일 랭킹 / 전체 랭킹**을 전환할 수 있습니다. 일일 랭킹은 한국 시간 오늘 등록된 기록의 최고점, 전체 랭킹은 역대 최고점입니다. 같은 점수는 먼저 등록한 기록이 우선입니다.
- 약 400px 모바일 폭과 운영체제의 라이트·다크 모드에서 화면을 확인합니다.
- 우측 상단에서 라이트·다크 모드를 직접 선택할 수 있습니다. 선택은 이 브라우저에 저장되며, 처음 방문하면 기기의 테마를 따릅니다.
- 하단 GitHub 아이콘은 제작자의 개인 프로필로, 메일 아이콘은 `zvzv9808@gmail.com`으로 연결됩니다.
- Supabase URL을 잠시 잘못 입력하거나 랭킹 요청을 차단하면 랭킹 오류가 표시되고 게임은 계속 동작해야 합니다. 확인 후 올바른 설정으로 복원합니다.

## 4. GitHub Pages에 공개하기

1. GitHub에서 게임 전용 **public 저장소**를 새로 만듭니다. 예: `kbo-fa-quiz`.
2. 이 게임 폴더의 **내용물**을 저장소의 `main` 브랜치 루트에 업로드하고 커밋합니다. `backend` 전체나 게임 폴더 자체를 한 단계 더 감싸서 올리지 않습니다.

```text
저장소 루트/
├── index.html
├── players.json
├── robots.txt
├── sitemap.xml
└── supabase/
    ├── schema.sql
    └── daily-ranking.sql
```

3. 저장소의 **Settings → Pages**로 이동합니다.
4. **Source**를 **Deploy from a branch**, 브랜치를 **main**, 폴더를 **/(root)**로 선택하고 **Save**를 누릅니다.
5. Pages 배포가 완료되면 표시되는 주소를 엽니다. 예를 들어 GitHub 계정이 `myname`, 저장소가 `kbo-fa-quiz`라면 주소는 `https://myname.github.io/kbo-fa-quiz/` 형태입니다.
6. 공개 주소에서 한 판을 플레이하고 닉네임 등록과 랭킹 조회를 확인한 뒤 링크를 공유합니다. 다른 브라우저나 휴대폰에서도 같은 랭킹이 보이는지 확인하면 됩니다.

이후 파일을 수정해 `main`에 커밋하면 다시 배포됩니다. 문제가 있으면 저장소의 **Actions**에서 Pages 배포 결과를 확인합니다. [GitHub Pages 배포 설정 안내](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)

## 랭킹 동작과 운영 범위

랭킹은 일일·전체 각각 닉네임별 최고점 TOP 10입니다. 기본 탭은 일일 랭킹이며 한국 시간 자정에 집계 날짜가 바뀝니다. 일일 랭킹은 DB 시간을 사용하고, 기존 기록을 삭제하거나 매일 초기화하는 배치 작업은 필요하지 않습니다. 같은 닉네임의 과거 최고점이 높아도 오늘의 기록은 일일 랭킹에 별도로 표시됩니다.

닉네임은 브라우저 `localStorage`에 기억하므로 브라우저나 기기를 바꾸면 다시 입력해야 합니다. Supabase 설정이 없거나 연결에 실패해도 문제 데이터가 로드되면 게임을 플레이할 수 있습니다.

이 구조는 로그인 없이 브라우저에서 점수를 등록합니다. RLS와 범위 제약은 적용하지만 점수의 실제 플레이 여부를 서버에서 검증하지 않으며, 같은 닉네임을 다른 사람이 사용할 수도 있습니다. 상금이 걸린 대회처럼 점수와 사용자 신원을 검증해야 하는 운영에는 서버 채점과 인증을 추가해야 합니다.

## Google 검색 등록

검색용 제목·설명, 대표 주소(canonical), WebSite 구조화 데이터, `robots.txt`와 `sitemap.xml`이 포함되어 있습니다. 대표 주소는 Vercel 주소로 통일합니다.

1. [Google Search Console](https://search.google.com/search-console/welcome)에 개인 Google 계정으로 로그인합니다.
2. **URL 접두어** 속성에 `https://kbo-fa-quiz.vercel.app/`를 등록합니다. Vercel의 공유 도메인이므로 도메인 DNS 인증 대신 URL 접두어를 사용합니다.
3. **HTML 태그** 방식에서 발급한 `google-site-verification` 메타 태그를 `index.html`의 `<head>`에 추가하고 배포한 뒤 소유권을 확인합니다. 태그는 이후에도 유지합니다.
4. **Sitemaps**에서 `https://kbo-fa-quiz.vercel.app/sitemap.xml`을 제출합니다.
5. **URL 검사**에 대표 주소를 입력하고 **실제 URL 테스트 → 색인 생성 요청**을 진행합니다.

수집·색인에는 며칠에서 몇 주가 걸릴 수 있고, 검색 결과 노출이나 순위는 보장되지 않습니다. 같은 URL을 반복 요청해도 더 빨리 처리되지 않습니다. [Google 공식 안내](https://developers.google.com/search/docs/crawling-indexing/ask-google-to-recrawl)
