// 공유 링크 쿼리(s, g, m, d)를 검증합니다. 값이 하나라도 이상하면 null을 돌려줍니다.
// 점수는 서명하지 않은 공유용 값이라 조작될 수 있습니다. 랭킹과는 무관합니다.
export function parseResult(searchParams) {
  const s = searchParams.get('s') ?? '';
  const g = searchParams.get('g') ?? '';
  const m = searchParams.get('m') ?? '';
  const d = searchParams.get('d') ?? '';
  if (!/^\d{1,4}$/.test(s) || Number(s) > 1000) return null;
  if (!/^[gfwb]{10}$/.test(g)) return null;
  if (m !== 'd' && m !== 'p') return null;
  if (m === 'd' && !/^\d{4}-\d{2}-\d{2}$/.test(d)) return null;
  const [, month, day] = d.split('-').map(Number);
  return {
    score: Number(s),
    grades: [...g],
    daily: m === 'd',
    dateLabel: m === 'd' ? `${month}월 ${day}일` : '',
    query: new URLSearchParams(m === 'd' ? { s, g, m, d } : { s, g, m }).toString()
  };
}

export const resultTitle = result => `FA 몸값 퀴즈 ${result.score} / 1000점`;
export const resultMode = result => result.daily ? `오늘의 도전 · ${result.dateLabel}` : '자유 연습';
