# FA 몸값 퀴즈

공개 주소: [FA 몸값 퀴즈](https://kbo-fa-quiz.vercel.app/)

KBO 선수의 직전 성적과 계약 기간을 보고 FA 계약 총액을 맞히는 웹 게임입니다. 프런트는 빌드 도구 없는 정적 파일이며, 오늘의 도전과 검증 랭킹은 Supabase에서 처리합니다. 개인 GitHub 저장소의 `main` 변경 사항을 Vercel이 자동 배포합니다.

## 게임 모드

| 모드 | 문제와 횟수 | 랭킹 |
| --- | --- | --- |
| 오늘의 도전 | 한국 시간 같은 날짜에는 모두 같은 10문제. 브라우저 계정당 하루 한 번 진행하며 자정에 마감합니다. | 서버에서 채점한 새 기록만 등록합니다. |
| 자유 연습 | 매번 무작위 10문제. 횟수 제한 없이 다시 할 수 있습니다. | 등록하지 않습니다. |

문제는 원본 `players.json`의 82건을 읽습니다. 선수·계약·성적·기사 URL 값을 수정하거나 문제를 추가하지 않았습니다. 한 판에서 같은 선수의 다른 연도 계약은 중복 출제하지 않으며, 동명이인 최원준은 포지션으로 구분합니다.

문제당 점수는 `max(0, round(100 − |내 답 − 정답| / 정답 × 100))`입니다. 한 판 최대 1000점이며, 95점 이상은 “정확합니다!”, 80점 이상은 “근접했습니다.”, 그 아래는 “차이가 큽니다.”로 표시합니다.

## 이어하기·복기·공유

- 시작, 입력, 정답 공개, 다음 문제, 완료 시 브라우저에 진행 상황을 자동 저장합니다. 자유 연습은 7일 동안 이어할 수 있고, 오늘의 도전은 당일 진행을 이어갑니다. 오늘의 도전은 서버의 진행 상태를 우선합니다.
- 최근 완료 결과는 별도로 보관해 홈에서 다시 볼 수 있습니다. 결과의 선수 행을 펼치면 보장·옵션과 계약 기사 링크를 확인할 수 있습니다. **100점 미만만 보기**로 복기할 문제를 좁힐 수 있습니다.
- 결과 공유 기능으로 점수와 게임 링크를 전달할 수 있습니다. 공유 이미지는 기존 브랜드 색과 문구로 만든 정적 이미지이며 선수 사진을 사용하지 않습니다.
- 닉네임과 테마는 이 브라우저에 기억합니다. 저장을 제한하는 브라우저에서는 일부 기능이 유지되지 않을 수 있습니다.

오늘의 도전은 이메일·비밀번호 입력 없이 Supabase 익명 계정을 만듭니다. **브라우저 데이터를 지우거나 다른 기기·브라우저를 사용하면 같은 계정으로 복구되지 않습니다.** 닉네임만으로 계정이나 진행 상황을 되찾을 수 없으며, 실제 신원을 확인하는 방식도 아닙니다. [Supabase 익명 계정 안내](https://supabase.com/docs/guides/auth/auth-anonymous)

## Supabase 설정

1. [Supabase 대시보드](https://supabase.com/dashboard)에서 프로젝트를 만듭니다. DB 비밀번호는 안전한 곳에 보관하고 웹 파일에 넣지 않습니다.
2. **Authentication → Sign In / Providers → Anonymous Sign-Ins**에서 익명 로그인을 활성화합니다. 오늘의 도전에는 이 설정이 필요합니다.
3. **SQL Editor**에서 프로젝트 상태에 맞는 SQL 파일 하나를 전체 실행합니다.

| 프로젝트 상태 | 실행 파일 |
| --- | --- |
| 새 프로젝트 | `supabase/schema.sql` |
| 기존 게임을 운영하던 프로젝트 | `supabase/verified-ranking.sql` |

두 파일은 같은 검증 랭킹 스키마를 설치합니다. 서버 채점용 문제 데이터는 SQL에 원본 82건 그대로 포함되어 별도로 가져오지 않아도 됩니다. 검증 랭킹으로 전환하면 기존의 클라이언트 직접 점수 등록을 닫습니다. 기존 기록은 삭제하지 않고 **이전 기록** 탭에서 별도로 조회합니다. 일일·전체 랭킹에는 오늘의 도전에서 서버가 채점한 새 기록만 반영합니다. 과거 버전의 `daily-ranking.sql`은 다시 실행하지 않습니다.

4. 프로젝트의 **Connect** 창에서 Project URL을, **Settings → API Keys**에서 브라우저용 공개 키를 복사합니다.
5. `index.html` 상단의 두 상수에 입력합니다.

```js
const SUPABASE_URL = 'https://프로젝트식별자.supabase.co';
const SUPABASE_ANON_KEY = '복사한_anon_또는_publishable_키';
```

기존 `anon` 키는 **Legacy API Keys**에 있습니다. 신규 설정에는 `sb_publishable_...` 형식의 publishable 키를 권장하며 변수 이름은 `SUPABASE_ANON_KEY` 그대로 사용합니다. Supabase는 기존 키를 2026년 말까지 폐기 예정으로 안내합니다. **`service_role`, `sb_secret_...`, DB 비밀번호는 HTML이나 GitHub에 넣지 마세요.** [API 키 안내](https://supabase.com/docs/guides/getting-started/api-keys), [새 키로 전환하기](https://supabase.com/docs/guides/getting-started/migrating-to-new-api-keys)

공개 API 키와 익명 사용자 계정은 다른 개념입니다. 방문자가 익명 로그인하면 Supabase의 `authenticated` 역할을 사용하며, SQL의 RLS와 제한된 함수가 요청 범위를 제어합니다. [익명 계정의 접근 권한](https://supabase.com/docs/guides/auth/auth-anonymous#access-control)

## 로컬에서 확인하기

터미널에서 게임 폴더로 이동해 HTTP 서버를 실행합니다.

```bash
cd /게임을_저장한_경로/kbo-fa-quiz
python3 -m http.server 8000 --bind 127.0.0.1
```

[로컬 게임 열기](http://127.0.0.1:8000/)로 접속하며, 서버 종료는 터미널에서 `Ctrl+C`입니다. `index.html`을 더블클릭해 `file://`로 열면 브라우저가 `fetch('./players.json')`를 차단할 수 있으므로 HTTP로 열어야 합니다. 폰트·CDN과 Supabase 기능에는 인터넷 연결이 필요합니다. 자유 연습은 문제 데이터가 로드되면 랭킹 서버 연결과 별도로 동작합니다.

주요 확인 항목은 다음과 같습니다.

- 두 모드에서 10문제를 진행하고 공개 버튼과 Enter 모두 답을 제출합니다.
- 타율·OPS는 `.356`, 평균자책점은 `3.50`처럼 표시됩니다. 잔류 선수는 `두산 잔류` 형식으로 표시됩니다.
- 정답 공개 후 계약 기간·총액·보장·옵션·내 답·판정·점수와 새 탭 기사 링크를 확인합니다.
- 진행 도중 새로고침한 뒤 이어하고, 완료한 결과를 다시 열어 복기합니다.
- 오늘의 도전을 완료해 닉네임을 등록한 뒤 일일·전체 랭킹 반영을 확인합니다. 같은 브라우저 계정으로 그날 새 도전을 시작할 수 없는지도 확인합니다.
- 자유 연습 결과는 검증 랭킹에 등록되지 않고, 기존 기록은 이전 기록 탭에만 보입니다.
- 결과 공유, 약 400px 모바일 폭, 라이트·다크 모드를 확인합니다.
- 랭킹 연결 실패 시 오류 안내가 표시되고 자유 연습은 계속 동작하는지 확인합니다.

## 배포 파일과 공개 주소

배포 루트에는 다음 파일이 있어야 합니다. `backend` 전체를 업로드하지 않습니다.

```text
저장소 루트/
├── index.html
├── players.json
├── robots.txt
├── sitemap.xml
├── assets/
│   ├── favicon.svg
│   ├── og-image.png
│   └── og-image.svg       # 공유 이미지 편집용 소스
└── supabase/
    ├── schema.sql
    ├── daily-ranking.sql  # 이전 버전 참고용
    └── verified-ranking.sql
```

현재 운영 주소는 `https://kbo-fa-quiz.vercel.app/`이며, GitHub `main`에 변경 사항을 커밋하면 Vercel이 다시 배포합니다. Supabase SQL과 익명 로그인 설정은 정적 파일 배포와 별도로 적용해야 합니다.

GitHub Pages로 직접 배포하려면 게임 전용 public 저장소 루트에 위 파일을 올리고 **Settings → Pages → Deploy from a branch → main → /(root) → Save**를 선택합니다. 배포 주소는 `https://계정.github.io/저장소명/` 형태입니다. 호스팅 주소를 변경할 때는 `index.html`의 canonical·OG 주소·구조화 데이터와 `robots.txt`, `sitemap.xml`의 대표 주소도 함께 바꿉니다. [GitHub Pages 설정](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)

## 무료 운영과 장애 확인

실제 요금제는 각 프로젝트 대시보드에서 확인합니다. Supabase **Free**는 7일 동안 DB 활동이 적으면 일시정지될 수 있습니다. 경고 메일과 프로젝트 상태를 확인하고, 일시정지되었다면 대시보드의 **Resume project**로 복구합니다. 무료 구성이 항상 켜진 랭킹 서버를 보장하지는 않습니다. Vercel과 Supabase의 사용량 화면에서 현재 한도와 사용량을 확인할 수 있습니다. [프로젝트 일시정지 공식 안내](https://supabase.com/docs/guides/platform/free-project-pausing)

게임은 누구나 다운로드할 수 있는 정적 문제 파일을 사용합니다. 서버 채점은 클라이언트가 점수를 임의로 제출하는 것을 제한하지만, **공개된 정답을 미리 보거나 새 익명 계정을 만드는 행위까지 막지는 못합니다.** 상금이나 실명 기준의 공식 대회용 검증을 제공하는 구조는 아닙니다.

## 검색과 공유 메타데이터

검색 제목·설명·canonical·WebSite 구조화 데이터·`robots.txt`·`sitemap.xml`과 공유 이미지·파비콘이 포함되어 있습니다. 대표 주소는 Vercel 주소로 통일합니다. `assets/og-image.svg`를 편집해 이미지를 바꾸더라도 실제 공유 미리보기에는 호환성이 높은 1200×630 PNG인 `assets/og-image.png`를 사용합니다.

Search Console은 URL 접두어 속성으로 등록하고 HTML 태그 소유권 인증을 유지합니다. 대표 주소의 사이트맵을 제출한 뒤 검색 노출·클릭을 확인합니다. 개별 색인 요청은 할당량 제한이 있으며, 같은 URL을 반복 요청해도 빨라지지 않습니다. 색인이나 검색 순위는 보장되지 않습니다. [Google 공식 안내](https://developers.google.com/search/docs/crawling-indexing/ask-google-to-recrawl)
