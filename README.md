# 스위치온 (Switch-On) 다이어트 동반자 앱

혼자 하면 3일 만에 포기하는 '스위치온 다이어트'를 끝까지 완주하게 돕는 **모바일 동반자 앱**.

- **프레임워크**: Flutter (iOS · Android 동시 지원)
- **백엔드**: Supabase (인증 · Postgres · Storage)
- **상태관리**: Riverpod / **로컬 우선(local-first)** 동기화 지향

> ⚠️ 이 앱은 의료 행위나 의학적 조언을 제공하지 않습니다. 시작 전·진행 중 전문가와 상담하세요.

---

## 현재 구현 상태

### P0 — 기반 + 온보딩 ✅
- [x] 프로젝트 스캐폴드 (Flutter + Riverpod + Supabase)
- [x] Supabase 스키마 + RLS + 트리거 (`supabase/migrations/0001_initial_schema.sql`)
- [x] 주차별 규칙 시드 (`supabase/seed.sql`)
- [x] 온보딩 — **안전 고지(의료 조언 아님)** → **나이 게이트(만 19세)** → 프로그램 설정
- [x] 이메일/비밀번호 인증

### P1 — 단계 엔진 + 일일 체크리스트 ✅
- [x] **단계 추적 엔진**(`stage_engine.dart`) — 시작일 기준 주차/일차, **일시정지·재개**(`0002_pause_resume.sql`)
- [x] **일일 체크리스트** — 물(2L 목표)·수면(6h)·단식·운동 + **달성률 링 시각화**
- [x] 홈: 오늘의 단계 + 미션 카드 + 체크리스트 + 식품 가이드 + 전체 진행 바
- [x] 단계 엔진 / 일일 로그 단위 테스트

### P2 — 타이머 · 식단 기록 · 로컬 알림 ✅
- [x] **단식 타이머**(14h/24h) — 라이브 카운트다운, 종료 시각 로컬 알림 예약(`fasting_sessions`, `0003`)
- [x] **셰이크 카운터** + **식단 기록**(사진 업로드 · 메모), 사진은 비공개 버킷 서명 URL로 표시
- [x] **반복 리마인더**(셰이크·물·취침 4h 전 마감) 설정 화면 + `NotificationService`
- [x] 하단 탭 셸: 오늘 / 단식 / 기록 / 알림

### 2차 — 규칙 위반 감지 ✅
- [x] **음식 태그 분류 + 단계별 규칙 엔진**(`diet_rules.dart`) — `allowOnly`/`forbidden`/`caution`
- [x] 식단 기록 시 태그 선택 → 현재 주차 기준 **위반/주의 부드러운 안내**, `meal_logs.food_tags`·`rule_violation` 저장
- [x] 식단 목록에 위반 배지 + 태그 표시

### 2차 — 통계 대시보드 ✅
- [x] **순수 함수 집계 엔진**(`stats.dart` `computeStats`) — 원자료 → 요약, 테스트 완료
- [x] 달성률 추이(최근 14일 커스텀 막대, 의존성 0), 항목별 달성 일수(물·수면·단식·운동)
- [x] 누적 지표: 셰이크 합 · 단식 완료 횟수 · 규칙 위반 빈도
- [x] 통계 탭 추가(오늘/단식/기록/통계/알림)

### 다음 단계
- **2차**: 주차 분기 안내(근육량 회복 → 반복/진행/유지)
- **3차**: 커뮤니티(그룹·인증샷·응원) + 서버 원격 푸시

---

## ⚠️ 네이티브 설정 (알림·사진) — `flutter create .` 후 반드시 적용

로컬 알림과 사진 선택은 네이티브 권한 설정이 필요합니다.

**Android** (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<!-- flutter_local_notifications: 부팅 후 알림 재예약 -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```
`<application>` 내부에 예약 알림 리시버 등록(패키지 문서 참고).
`compileSdk`/`minSdk`는 image_picker·local_notifications 권장값(예: minSdk 21+).

**iOS** (`ios/Runner/Info.plist`)
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>식사 사진을 기록하기 위해 사진 접근이 필요합니다.</string>
```
`ios/Runner/AppDelegate.swift`에 알림 등록 코드 추가(flutter_local_notifications 문서의 iOS 설정 참고).

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
    program/stage_engine.dart     # 주차/일차 계산 + 일시정지·재개 (순수 함수)
    program/diet_rules.dart       # 음식 태그 + 단계별 규칙 위반 감지 (순수 함수)
    providers.dart                # Riverpod providers
  data/
    models/{profile, daily_log, fasting_session, meal_log}.dart
    services/{supabase,auth}_service.dart
  services/notification_service.dart  # 로컬 알림 (단식·셰이크·물·취침)
  features/
    shell/main_shell.dart         # 하단 탭(오늘/단식/기록/알림)
    onboarding/{onboarding_gate, onboarding_flow}.dart
    auth/sign_in_screen.dart
    home/{home_screen, daily_log_controller}.dart
    home/widgets/{mission_card, checklist_card}.dart
    fasting/{fasting_screen, fasting_controller}.dart
    meals/{meals_screen, meals_controller}.dart
    stats/{stats, stats_controller, stats_screen}.dart  # 집계는 순수 함수
    reminders/{reminders_screen, reminder_service}.dart
    setup_required_screen.dart
supabase/
  migrations/0001_initial_schema.sql
  migrations/0002_pause_resume.sql
  migrations/0003_fasting_sessions.sql
  seed.sql
```

## 안전·윤리 원칙 (타협하지 않음)
- 온보딩에 **"의료 조언 아님 / 의사 상담 권고"** 명시.
- 근육량 부족·지병·복약자에 대한 주의 안내.
- **극단적 감량·과도한 단식을 부추기지 않는 톤** — 체중 입력은 선택, 목표는 자유 서술.
- **만 19세 미만 사용 제한 안내** (나이 게이트).
