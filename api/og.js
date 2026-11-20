import { ImageResponse } from '@vercel/og';
import { parseResult, resultMode } from './_result.js';

// Node 런타임에서 실행합니다(Edge 런타임에서는 렌더링 결과가 빈 PNG로 나왔습니다).
const SITE = 'https://kbo-fa-quiz.vercel.app';
const COLORS = { bg: '#141a17', card: '#1d2420', ink: '#e8ece6', muted: '#9aa59d', line: '#2f3833', accent: '#ff5a6e' };
const GRADE_COLORS = { g: '#5fd08f', f: '#6aa8ff', w: '#ff9b50', b: '#ff5a6e' };

// 이미지에 들어가는 글자만 담은 폰트 조각을 Google Fonts에서 받습니다(TTF).
async function loadFont(text) {
  const css = await (await fetch(`https://fonts.googleapis.com/css2?family=Black+Han+Sans&text=${encodeURIComponent(text)}`)).text();
  const url = css.match(/src: url\((.+?)\) format\('(opentype|truetype)'\)/)?.[1];
  if (!url) throw new Error('Font unavailable');
  return (await fetch(url)).arrayBuffer();
}

const el = (type, style, children) => ({ type, props: { style: { display: 'flex', ...style }, children } });

function card(result) {
  const squares = result.grades.map(code => el('div', { width: 76, height: 76, borderRadius: 14, background: GRADE_COLORS[code] }));
  return el('div', { width: '100%', height: '100%', background: COLORS.bg, padding: 56 }, [
    el('div', {
      flex: 1, flexDirection: 'column', justifyContent: 'space-between', padding: '48px 56px',
      background: COLORS.card, border: `2px solid ${COLORS.line}`, borderRadius: 28
    }, [
      el('div', { justifyContent: 'space-between', alignItems: 'center' }, [
        el('div', { fontSize: 44, color: COLORS.ink }, 'FA 몸값 퀴즈'),
        el('div', { fontSize: 32, color: COLORS.accent }, resultMode(result))
      ]),
      el('div', { justifyContent: 'space-between', alignItems: 'flex-end' }, [
        el('div', { alignItems: 'flex-end', gap: 20 }, [
          el('div', { fontSize: 168, lineHeight: 1, color: COLORS.ink }, String(result.score)),
          el('div', { fontSize: 52, color: COLORS.muted, paddingBottom: 18 }, '/ 1000점')
        ]),
        el('div', { fontSize: 26, color: COLORS.muted, paddingBottom: 22 }, 'kbo-fa-quiz.vercel.app')
      ]),
      el('div', { gap: 12 }, squares)
    ])
  ]);
}

const fallback = reason => new Response(null, {
  status: 302,
  headers: { Location: `${SITE}/assets/og-image.png`, 'Cache-Control': 'no-store', 'x-og-error': reason.slice(0, 200) }
});

export async function GET(request) {
  const result = parseResult(new URL(request.url).searchParams);
  if (!result) return fallback('invalid query');
  try {
    const text = `FA 몸값 퀴즈${resultMode(result)}${result.score}/ 1000점kbo-fa-quiz.vercel.app`;
    const font = await loadFont(text);
    // 스트리밍 도중 실패하면 빈 PNG가 캐시되므로, 끝까지 그린 뒤에 응답합니다.
    const png = await new ImageResponse(card(result), {
      width: 1200, height: 630,
      fonts: [{ name: 'Black Han Sans', data: font, weight: 400, style: 'normal' }]
    }).arrayBuffer();
    if (png.byteLength === 0) throw new Error('Empty image');
    return new Response(png, {
      headers: { 'Content-Type': 'image/png', 'Cache-Control': 'public, max-age=31536000, immutable' }
    });
  } catch (error) {
    // 폰트나 렌더링이 실패하면 기본 OG 이미지로 대신하고, 원인은 헤더와 로그에 남깁니다.
    console.error('og render failed', error);
    return fallback(String(error?.message ?? error));
  }
}
