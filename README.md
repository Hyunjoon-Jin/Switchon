# 스위치온 (Switch-On) 다이어트 동반자 앱

혼자 하면 3일 만에 포기하는 '스위치온 다이어트'를 끝까지 완주하게 돕는 **모바일 동반자 앱**.

- **프레임워크**: Flutter (iOS · Android 동시 지원)
- **백엔드**: Supabase (인증 · Postgres · Storage)
- **상태관리**: Riverpod / **로컬 우선(local-first)** 동기화 지향

> ⚠️ 이 앱은 의료 행위나 의학적 조언을 제공하지 않습니다. 시작 전·진행 중 전문가와 상담하세요.

---

## 현재 구현 상태 (P0)

- [x] 프로젝트 스캐폴드 (Flutter + Riverpod + Supabase)
- [x] Supabase 스키마 + RLS + 트리거 (`supabase/migrations/0001_initial_schema.sql`)
- [x] 주차별 규칙 시드 (`supabase/seed.sql`)
- [x] 온보딩 — **안전 고지(의료 조언 아님)** → **나이 게이트(만 19세)** → 프로그램 설정
- [x] 이메일/비밀번호 인증
- [x] 홈 자리표시: 시작일 기준 주차/일차 + 오늘의 미션 카드 + 식품 가이드

### 다음 단계
- **P1**: 단계 추적 엔진(일시정지·재개) · 일일 체크리스트 · 달성률
- **P2**: 단식/셰이크 타이머 · 식단 기록 · 로컬 알림
- **P3+**: 규칙 위반 감지 · 통계 · (3차) 커뮤니티

---

## 로컬 실행 방법

### 1. 사전 준비
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable, Dart 3.4+)
- Android Studio / Xcode (각 플랫폼 빌드용)
- Supabase 프로젝트 1개

### 2. 네이티브 폴더 생성
이 저장소에는 `lib/`·`supabase/` 등 소스만 들어 있습니다. 플랫폼 폴더(`android/`·`ios/`)는 아래로 생성하세요.

```bash
flutter create . --platforms=android,ios --project-name switchon
flutter pub get
```

### 3. Supabase 설정
1. Supabase 프로젝트의 SQL Editor에서 다음을 순서대로 실행:
   - `supabase/migrations/0001_initial_schema.sql`
   - `supabase/seed.sql`
   - (또는 Supabase CLI: `supabase db push` + `supabase db seed`)
2. Authentication → Providers에서 **Email** 활성화.
3. 프로젝트의 `URL`과 `anon public key`를 확인.

### 4. 실행 (환경변수 주입)
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```
`.env.example`을 참고하세요. 비밀값은 커밋하지 않습니다.

### 5. 테스트 / 정적 분석
```bash
flutter analyze
flutter test
```

---

## 디렉터리 구조
```
lib/
  core/
    config/app_config.dart        # 환경변수 · 나이 기준
    theme/app_theme.dart          # 차분한 그린 테마
    program/switchon_program.dart # 단계/미션 규칙 (오프라인 미러)
    providers.dart                # Riverpod providers
  data/
    models/profile.dart
    services/{supabase,auth}_service.dart
  features/
    onboarding/{onboarding_gate, onboarding_flow}.dart
    auth/sign_in_screen.dart
    home/home_screen.dart
    setup_required_screen.dart
supabase/
  migrations/0001_initial_schema.sql
  seed.sql
```

## 안전·윤리 원칙 (타협하지 않음)
- 온보딩에 **"의료 조언 아님 / 의사 상담 권고"** 명시.
- 근육량 부족·지병·복약자에 대한 주의 안내.
- **극단적 감량·과도한 단식을 부추기지 않는 톤** — 체중 입력은 선택, 목표는 자유 서술.
- **만 19세 미만 사용 제한 안내** (나이 게이트).
