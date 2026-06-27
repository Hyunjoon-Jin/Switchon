# AI 식단 분석 기능 설정 가이드

음식 사진을 Claude(비전)가 보고 **현재 단계에 부합하는지 판정 → 점수 → 피드백 → 식단 조절 제안**을 주는 기능입니다.
API 키는 **절대 앱에 넣지 않고** Supabase Edge Function 에만 보관합니다. (앱 코드는 누구나 뜯어볼 수 있기 때문)

---

## 한눈에 보는 구조

```
Flutter 앱  →  Supabase Edge Function(analyze-meal)  →  Claude API (claude-opus-4-8)
 (식사 id 전송)   (ANTHROPIC_API_KEY 보관 · 사진 직접 읽음)    (JSON 판정 반환)
```

- 앱은 **식사 id + 현재 단계 정보**만 보냅니다.
- 함수가 비공개 버킷(`meal-photos`)에서 사진을 직접 읽어 분석합니다.
- 결과는 `meal_logs` 테이블에 저장되고, `verdict='violation'` 이면 `rule_violation`도 자동으로 켜집니다.

---

## 1단계 · DB 컬럼 추가 (Supabase SQL Editor)

Supabase 대시보드 → **SQL Editor** → 아래를 붙여넣고 **Run**:

```sql
alter table public.meal_logs
  add column if not exists ai_score int
    check (ai_score is null or (ai_score between 0 and 100)),
  add column if not exists ai_verdict text
    check (ai_verdict is null or ai_verdict in ('fit', 'caution', 'violation')),
  add column if not exists ai_foods text,
  add column if not exists ai_feedback text,
  add column if not exists ai_suggestion text,
  add column if not exists ai_analyzed_at timestamptz;
```

(저장소의 `supabase/migrations/0009_ai_analysis.sql` 과 동일한 내용입니다.)

---

## 2단계 · Anthropic API 키 발급

1. https://console.anthropic.com 접속 → 로그인
2. **Settings → API Keys → Create Key**
3. 생성된 키(`sk-ant-...`)를 복사 — **이 화면을 벗어나면 다시 못 보니 잘 보관**
4. 결제 수단 등록(**Billing**)이 되어 있어야 호출됩니다. (사진 1장 분석 ≈ 수 원 수준의 종량제)

---

## 3단계 · Edge Function 배포

컴퓨터에서 한 번만 하면 됩니다. (Supabase CLI 필요)

```bash
# 1) Supabase CLI 설치 (이미 있으면 생략)
#    https://supabase.com/docs/guides/cli  참고
npm install -g supabase

# 2) 로그인 & 프로젝트 연결
supabase login
supabase link --project-ref fzaujefqucfbapohbkpi   # ← 본인 프로젝트 ref

# 3) API 키를 함수 시크릿으로 등록 (앱에는 절대 넣지 않음!)
supabase secrets set ANTHROPIC_API_KEY=sk-ant-여기에_복사한_키

# 4) 함수 배포
supabase functions deploy analyze-meal
```

> `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` / `SUPABASE_ANON_KEY` 는 보통 자동 주입되어
> 따로 설정할 필요가 없습니다. 혹시 함수 로그에 "미설정" 오류가 보이면 같은 방식으로
> `supabase secrets set` 으로 넣어 주세요.

CLI 없이 대시보드에서 하려면: **Edge Functions → Deploy** 에서 `supabase/functions/analyze-meal/index.ts`
내용을 올리고, **Edge Functions → (함수) → Secrets** 에 `ANTHROPIC_API_KEY` 를 추가해도 됩니다.

---

## 4단계 · 사용해 보기

1. 앱에서 **기록 탭 → 식사 기록**으로 사진을 첨부해 저장
2. 그 식사를 열면(상세) **`AI 식단 분석`** 버튼이 보입니다
3. 누르면 잠깐 뒤 점수·판정·피드백·조절 제안이 나타납니다
4. 결과는 저장되어 목록/캘린더에서 점수 배지로 보이고, 언제든 **다시 분석**할 수 있어요

---

## 안전 안내

- AI 분석 결과는 **참고용 코칭**이며 **의학적 진단이 아닙니다.** (결과 카드에도 항상 표시됩니다)
- 극단적 절식·폭식 등은 권하지 않도록 프롬프트에 가드레일을 넣어 두었습니다.
- 건강 상태·지병·복약 여부에 따라 단식·식단 제한이 무리가 될 수 있으니 전문가와 상담하세요.

## 비용 메모

- 분석은 **버튼을 눌렀을 때만** 호출되므로 비용을 직접 통제할 수 있습니다.
- 한 번에 최대 2장까지만 분석합니다(비용·속도). 더 늘리려면 함수의 `MAX_PHOTOS` 를 조정하세요.
