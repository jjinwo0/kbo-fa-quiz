import { parseResult, resultMode, resultTitle } from './_result.js';

export const config = { runtime: 'edge' };

const SITE = 'https://kbo-fa-quiz.vercel.app';
const esc = value => String(value).replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));

// 메신저 미리보기용 OG 태그를 주고, 사람이 열면 게임 첫 화면으로 보냅니다.
export default function handler(request) {
  const result = parseResult(new URL(request.url).searchParams);
  if (!result) return Response.redirect(`${SITE}/`, 302);
  const title = esc(resultTitle(result));
  const description = esc(`${resultMode(result)} 결과 · 직전 시즌 성적만 보고 KBO FA 계약 총액을 맞혀 보세요.`);
  const image = esc(`${SITE}/api/og?${result.query}`);
  const html = `<!doctype html>
<html lang="ko"><head>
<meta charset="utf-8">
<title>${title}</title>
<meta name="description" content="${description}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="FA 몸값 퀴즈">
<meta property="og:title" content="${title}">
<meta property="og:description" content="${description}">
<meta property="og:url" content="${esc(`${SITE}/s?${result.query}`)}">
<meta property="og:image" content="${image}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:image" content="${image}">
<meta http-equiv="refresh" content="0; url=${SITE}/">
</head><body><a href="${SITE}/">FA 몸값 퀴즈로 이동</a></body></html>`;
  return new Response(html, { headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'public, max-age=86400' } });
}
